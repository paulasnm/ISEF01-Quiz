const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "https://isef01-quiz-1.onrender.com", 
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.static('.'));

console.log('🚀 Schatzinsel Server mit Socket.IO startet...');

// Demo-Benutzer
const users = [
  { id: 1, username: 'demo', password: 'demo123' },
  { id: 2, username: 'admin', password: 'admin123' }
];

// Lobby-System
let waitingPlayers = [];
let activeGroups = [];

// Socket.IO Verbindungen
io.on('connection', (socket) => {
  console.log(`🔌 Neuer Spieler verbunden: ${socket.id}`);

  // Chat beitreten
  socket.on('join-chat', (data) => {
    socket.username = data.username;
    console.log(`💬 ${data.username} ist dem Chat beigetreten`);
    
    // Anderen Spielern mitteilen
    socket.broadcast.emit('player-joined', {
      username: data.username
    });
  });

  // Chat-Nachricht
  socket.on('chat-message', (data) => {
    console.log(`💬 Chat von ${data.username}: ${data.text}`);
    
    // Nachricht an alle anderen Spieler weiterleiten
    socket.broadcast.emit('chat-message', {
      text: data.text,
      username: data.username,
      timestamp: data.timestamp
    });
  });

  // Lobby beitreten
  socket.on('requestJoin', () => {
    console.log(`👥 Spieler ${socket.id} möchte der Lobby beitreten`);
    
    // Füge Spieler zur Warteschlange hinzu
    waitingPlayers.push({
      id: socket.id,
      socket: socket,
      joinedAt: new Date()
    });

    console.log(`⏳ Wartende Spieler: ${waitingPlayers.length}`);

    // Versuche Gruppe zu bilden (mindestens 2 Spieler)
    if (waitingPlayers.length >= 2) {
      // Nimm die ersten 2-4 Spieler
      const groupSize = Math.min(4, waitingPlayers.length);
      const newGroup = waitingPlayers.splice(0, groupSize);
      
      const groupNames = newGroup.map(p => `Spieler${p.id.substring(0, 4)}`);
      
      console.log(`🎮 Neue Gruppe erstellt: ${groupNames.join(', ')}`);
      
      // Alle Spieler in der Gruppe benachrichtigen
      newGroup.forEach(player => {
        player.socket.emit('joinResponse', {
          success: true,
          group: groupNames,
          groupId: activeGroups.length,
          message: 'Gruppe gefunden! Das Spiel beginnt...'
        });
      });
      
      // Gruppe zu aktiven Gruppen hinzufügen
      activeGroups.push({
        id: activeGroups.length,
        players: newGroup,
        createdAt: new Date()
      });
      
    } else {
      // Nicht genug Spieler - warten oder alleine spielen vorschlagen
      socket.emit('joinResponse', {
        success: false,
        message: 'Warte auf weitere Spieler oder spiele alleine...',
        waitingCount: waitingPlayers.length
      });
    }
  });

  // Spieler verlässt die Verbindung
  socket.on('disconnect', () => {
    console.log(`🔌 Spieler getrennt: ${socket.id}`);
    
    // Chat-Austritt mitteilen
    if (socket.username) {
      socket.broadcast.emit('player-left', {
        username: socket.username
      });
    }
    
    // Aus Warteschlange entfernen
    waitingPlayers = waitingPlayers.filter(p => p.id !== socket.id);
    
    // Aus aktiven Gruppen entfernen
    activeGroups = activeGroups.filter(group => {
      group.players = group.players.filter(p => p.id !== socket.id);
      return group.players.length > 0; // Gruppe löschen wenn leer
    });
  });
});

// Root-Route - IMMER Startseite anzeigen
app.get('/', (req, res) => {
  console.log('📍 Root-Route aufgerufen - leite zu Startseite weiter');
  
  // Versuche verschiedene Startseiten-Dateien zu finden
  const possibleStartFiles = [
    'ISEF01_Startseite.html'
  ];
  
  let startFound = false;
  
  for (const filename of possibleStartFiles) {
    const startPath = path.join(__dirname, filename);
    
    try {
      // Prüfe ob Datei existiert
      require('fs').accessSync(startPath);
      console.log(`✅ Startseite gefunden: ${filename}`);
      res.sendFile(startPath);
      startFound = true;
      break;
    } catch (err) {
      // Datei existiert nicht, versuche nächste
      continue;
    }
  }
  
  // Falls keine Startseite gefunden wird
  if (!startFound) {
    console.log('❌ Keine Startseite gefunden');
    res.status(404).send('Startseite nicht gefunden. Stelle sicher, dass ISEF01_Startseite.html existiert.');
  }
});

// Login API
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  console.log(`👤 Login-Versuch: ${username}`);
  
  const user = users.find(u => u.username === username && u.password === password);
  
  if (user) {
    console.log(`✅ Login erfolgreich: ${username}`);
    if (username === 'admin') {
      res.json({ success: true, user: { username, isAdmin: true } });
    } else {
      res.json({ success: true, user: { id: user.id, username, isAdmin: false } });
    }
  } else {
    console.log(`❌ Login fehlgeschlagen: ${username}`);
    res.status(401).json({ error: 'Ungültige Anmeldedaten' });
  }
});

// Admin Login API
app.post('/api/admin/login', (req, res) => {
  const { username, password } = req.body;
  if (username === 'admin' && password === 'admin123') {
    console.log('✅ Admin-Login erfolgreich');
    res.json({ success: true, user: { username: 'admin', isAdmin: true }});
  } else {
    console.log('❌ Admin-Login fehlgeschlagen');
    res.status(401).json({ error: 'Ungültige Admin-Anmeldedaten' });
  }
});

// Registrierung API (optional)
app.post('/api/register', (req, res) => {
  const { username, password } = req.body;
  
  // Prüfen ob Benutzer bereits existiert
  const existingUser = users.find(u => u.username === username);
  if (existingUser) {
    return res.status(400).json({ error: 'Benutzername bereits vergeben' });
  }
  
  // Neuen Benutzer hinzufügen (nur für Demo - geht bei Server-Neustart verloren)
  const newUser = {
    id: users.length + 1,
    username,
    password
  };
  users.push(newUser);
  
  console.log(`✅ Neuer Benutzer registriert: ${username}`);
  res.json({ 
    success: true, 
    user: { id: newUser.id, username: newUser.username }
  });
});

// Lobby Status API (Debug)
app.get('/api/lobby/status', (req, res) => {
  res.json({
    waitingPlayers: waitingPlayers.length,
    activeGroups: activeGroups.length,
    totalConnectedPlayers: io.engine.clientsCount
  });
});

// Quiz API (Beispiel für später)
app.get('/api/questions', (req, res) => {
  const questions = [
    {
      id: 1,
      question: "Wie viel ist 2 + 2?",
      answers: ["3", "4", "5", "6"],
      correct: 1
    },
    {
      id: 2,
      question: "Was ist die Hauptstadt von Deutschland?",
      answers: ["München", "Hamburg", "Berlin", "Köln"],
      correct: 2
    }
  ];
  res.json(questions);
});

// Alle anderen Dateien (HTML, CSS, JS, Bilder)
app.get('*', (req, res) => {
  console.log(`📁 Datei angefragt: ${req.path}`);
  res.sendFile(path.join(__dirname, req.path), (err) => {
    if (err) {
      console.log(`❌ Datei nicht gefunden: ${req.path}`);
      res.status(404).send(`Datei nicht gefunden: ${req.path}`);
    }
  });
});

// Error Handler
app.use((err, req, res, next) => {
  console.error('💥 Server-Fehler:', err);
  res.status(500).json({ error: 'Interner Server-Fehler' });
});

// Server starten (wichtig: server statt app!)
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Schatzinsel Server mit Socket.IO läuft auf Port ${PORT}`);
  console.log(`🎮 Lobby-System aktiviert`);
  console.log(`📋 Demo-Login: demo/demo123 oder admin/admin123`);
  console.log(`🌐 Socket.IO bereit für Multiplayer`);
});