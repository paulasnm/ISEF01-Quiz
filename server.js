require('dotenv').config();
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const path = require('path');
const bcrypt = require('bcrypt');
const { Pool } = require('pg');
const session = require('express-session');
const pgSession = require('connect-pg-simple')(session);

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.PORT || 3000;

// PostgreSQL Verbindung
const db = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT,
  ssl: false, 
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Middleware
app.use(cors({
  origin: "http://localhost:3000",
  credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static('public'));

// Session Middleware mit PostgreSQL
app.use(session({
  store: new pgSession({
    pool: db,
    tableName: 'session'
  }),
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: false,
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000 // 24 Stunden
  }
}));

// Auth Middleware
function requireAuth(req, res, next) {
  if (req.session.userId) {
    next();
  } else {
    res.status(401).json({ error: 'Nicht angemeldet' });
  }
}

// Utility Funktionen
const hashPassword = async (password) => await bcrypt.hash(password, 12);
const comparePassword = async (password, hash) => await bcrypt.compare(password, hash);

// ==================================
// Spieler- und Chat-Logik mit Socket.IO
// ==================================
let onlineUsers = {}; // socket.id -> username

io.on('connection', (socket) => {
  console.log(`Spieler verbunden: ${socket.id}`);

  // Spieler registrieren (Username kann später aus Session kommen)
  onlineUsers[socket.id] = { username: "Spieler-" + socket.id.slice(0, 4) };

  // === Lobby-Request ===
  socket.on("requestJoin", () => {
    const playerCount = Object.keys(onlineUsers).length;

    if (playerCount < 2) {
      socket.emit("joinResponse", { success: false });
    } else {
      const players = Object.values(onlineUsers).map((u) => u.username);
      const shuffled = [...players].sort(() => 0.5 - Math.random());
      const groupSize = Math.min(Math.floor(Math.random() * 3) + 2, players.length);
      const group = shuffled.slice(0, groupSize);

      socket.emit("joinResponse", { success: true, group });
    }
  });

  // === Chat ===
  socket.on('sendMessage', async (data) => {
    const { message } = data;
    const user = onlineUsers[socket.id];

    if (user && message.trim()) {
      const chatMessage = {
        username: user.username,
        text: message.trim(),
        time: new Date().toISOString()
      };

      // an alle senden
      io.emit('newMessage', chatMessage);

      // optional in DB speichern
      try {
        await db.query(
          'INSERT INTO chats (user_id, text, time) VALUES ($1, $2, NOW())',
          [null, message.trim()]
        );
      } catch (err) {
        console.error("Chat speichern Fehler:", err);
      }
    }
  });

  // Disconnect
  socket.on("disconnect", () => {
    console.log(`Spieler getrennt: ${socket.id}`);
    delete onlineUsers[socket.id];
  });
});

// ==================================
// API ROUTEN
// ==================================

// Startseite
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'ISEF01_Startseite.html'));
});

// Registrierung
app.post('/api/register', async (req, res) => {
  try {
    const { firstname, surname, username, email, password, avatar_id } = req.body;

    if (!firstname || !surname || !username || !email || !password) {
      return res.status(400).json({ error: 'Alle Felder sind erforderlich' });
    }

    const hashedPassword = await hashPassword(password);

    const result = await db.query(
      'INSERT INTO users (firstname, surname, username, email, password, avatar_id) VALUES ($1, $2, $3, $4, $5, $6) RETURNING user_id',
      [firstname, surname, username, email, hashedPassword, avatar_id || 31]
    );

    res.status(201).json({
      success: true,
      message: 'Registrierung erfolgreich!',
      userId: result.rows[0].user_id
    });

  } catch (error) {
    console.error('Registrierung Fehler:', error);
    res.status(500).json({ error: 'Serverfehler' });
  }
});

// Login
app.post('/api/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    const result = await db.query('SELECT * FROM users WHERE username = $1', [username]);

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Ungültige Anmeldedaten' });
    }

    const user = result.rows[0];
    const isValidPassword = await comparePassword(password, user.password);

    if (!isValidPassword) {
      return res.status(401).json({ error: 'Ungültige Anmeldedaten' });
    }

    req.session.userId = user.user_id;

    res.json({
      success: true,
      message: 'Erfolgreich eingeloggt!',
      user: { id: user.user_id, username: user.username }
    });
  } catch (error) {
    console.error('Login Fehler:', error);
    res.status(500).json({ error: 'Serverfehler' });
  }
});

// Logout
app.post('/api/logout', requireAuth, (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      return res.status(500).json({ error: 'Logout fehlgeschlagen' });
    }
    res.json({ success: true, message: 'Erfolgreich abgemeldet' });
  });
});

// Kurse laden
app.get('/api/courses', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT 
        c.course_id,
        c.course_name,
        COUNT(q.question_id) as question_count
      FROM courses c
      LEFT JOIN questions q ON c.course_id = q.course_id 
        AND q.status = 'approved'
      GROUP BY c.course_id, c.course_name
      ORDER BY c.course_name
    `);
    
    res.json(result.rows);
  } catch (error) {
    console.error('Kurse laden Fehler:', error);
    res.status(500).json({ error: 'Serverfehler beim Laden der Kurse' });
  }
});

// Fragen eines Kurses laden
app.get('/api/courses/:courseId/questions', async (req, res) => {
  try {
    const { courseId } = req.params;
    
    const result = await db.query(`
      SELECT 
        q.question_id,
        q.text,
        q.explanation,
        array_agg(
          json_build_object(
            'answer_id', a.answer_id,
            'text', a.text,
            'right_wrong', a.right_wrong
          ) ORDER BY a.answer_id
        ) as answers
      FROM questions q
      LEFT JOIN answers a ON q.question_id = a.question_id
      WHERE q.course_id = $1 AND q.status = 'approved'
      GROUP BY q.question_id, q.text, q.explanation
      ORDER BY q.question_id
    `, [courseId]);
    
    res.json(result.rows);
  } catch (error) {
    console.error('Fragen laden Fehler:', error);
    res.status(500).json({ error: 'Serverfehler beim Laden der Fragen' });
  }
});

// Neue Frage erstellen
app.post('/api/questions', requireAuth, async (req, res) => {
  const client = await db.connect();
  
  try {
    await client.query('BEGIN');
    
    const { text, answers, correctIndex, category, explanation } = req.body;
    
    if (!text || !answers || answers.length !== 4 || correctIndex < 0 || correctIndex > 3) {
      return res.status(400).json({ error: 'Ungültige Fragendaten' });
    }

    // Kurs finden oder erstellen
    let courseResult = await client.query(
      'SELECT course_id FROM courses WHERE course_name = $1',
      [category]
    );

    let courseId;
    if (courseResult.rows.length === 0) {
      const newCourse = await client.query(
        'INSERT INTO courses (course_name) VALUES ($1) RETURNING course_id',
        [category]
      );
      courseId = newCourse.rows[0].course_id;
    } else {
      courseId = courseResult.rows[0].course_id;
    }

    // Frage erstellen
    const questionResult = await client.query(`
      INSERT INTO questions (course_id, made_by_userid, text, explanation, status)
      VALUES ($1, $2, $3, $4, 'pending')
      RETURNING question_id
    `, [courseId, req.session.userId, text, explanation || null]);

    const questionId = questionResult.rows[0].question_id;

    // Antworten erstellen
    for (let i = 0; i < answers.length; i++) {
      await client.query(`
        INSERT INTO answers (question_id, text, right_wrong)
        VALUES ($1, $2, $3)
      `, [questionId, answers[i], i === correctIndex]);
    }

    await client.query('COMMIT');
    res.json({ success: true, message: 'Frage erfolgreich erstellt und wartet auf Freigabe' });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Frage erstellen Fehler:', error);
    res.status(500).json({ error: 'Serverfehler beim Erstellen der Frage' });
  } finally {
    client.release();
  }
});

// Avatare laden
app.get('/api/avatars', async (req, res) => {
  try {
    const result = await db.query('SELECT * FROM avatars ORDER BY avatar_id');
    res.json(result.rows);
  } catch (error) {
    console.error('Avatare laden Fehler:', error);
    res.status(500).json({ error: 'Serverfehler beim Laden der Avatare' });
  }
});

// HTML-Dateien servieren
app.get('/*.html', (req, res) => {
  const filename = req.params[0] + '.html';
  res.sendFile(path.join(__dirname, 'public', filename));
});

// Admin Login Route - nur für hardcodierte Admin-Credentials
app.post('/api/admin/login', async (req, res) => {
    try {
      const { username, password } = req.body;
      
      // Hardcodierte Admin-Credentials prüfen
      if (username === 'admin' && password === 'admin123') {
        // Admin-Session setzen
        req.session.isAdmin = true;
        req.session.adminUsername = 'admin';
        
        res.json({
          success: true,
          message: 'Admin erfolgreich eingeloggt!',
          isAdmin: true
        });
      } else {
        res.status(401).json({ error: 'Ungültige Admin-Anmeldedaten' });
      }
    } catch (error) {
      console.error('Admin Login Fehler:', error);
      res.status(500).json({ error: 'Serverfehler' });
    }
  });
  
  // Admin Auth Middleware
  function requireAdmin(req, res, next) {
    if (req.session.isAdmin) {
      next();
    } else {
      res.status(403).json({ error: 'Admin-Berechtigung erforderlich' });
    }
  }
  
  // Admin Logout
  app.post('/api/admin/logout', (req, res) => {
    req.session.destroy((err) => {
      if (err) {
        return res.status(500).json({ error: 'Logout fehlgeschlagen' });
      }
      res.json({ success: true, message: 'Admin erfolgreich abgemeldet' });
    });
  });

// Avatar-Mapping Route - wandelt avatar_id zu Dateiname um
app.get('/api/profile', requireAuth, async (req, res) => {
    try {
      const result = await db.query(`
        SELECT 
          u.firstname as prename, 
          u.surname, 
          u.username, 
          u.email,
          CASE 
            WHEN a.avatar_image_url IS NOT NULL THEN a.avatar_image_url
            WHEN u.avatar_id = 31 THEN 'avatar1.jpeg'
            WHEN u.avatar_id = 32 THEN 'avatar2.jpeg' 
            WHEN u.avatar_id = 33 THEN 'avatar3.jpeg'
            ELSE 'avatar1.jpeg'
          END as avatar
        FROM users u
        LEFT JOIN avatars a ON u.avatar_id = a.avatar_id
        WHERE u.user_id = $1
      `, [req.session.userId]);
  
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Benutzer nicht gefunden' });
      }
  
      const user = result.rows[0];
      res.json({
        prename: user.prename,
        surname: user.surname,
        username: user.username,
        email: user.email,
        avatar: user.avatar
      });
  
    } catch (error) {
      console.error('Profil laden Fehler:', error);
      res.status(500).json({ error: 'Serverfehler' });
    }
  });

// ==================================
// Server starten
// ==================================
server.listen(PORT, async () => {
  try {
    await db.query('SELECT NOW()');
    console.log(`Server läuft auf http://localhost:${PORT}`);
    console.log(`PostgreSQL-Datenbank verbunden: ${process.env.DB_NAME}`);
    console.log(`Chat & Lobby bereit!`);
  } catch (error) {
    console.error('Datenbankverbindung fehlgeschlagen:', error);
    process.exit(1);
  }
});

process.on('SIGTERM', async () => {
  console.log('Server wird beendet...');
  await db.end();
  process.exit(0);
});