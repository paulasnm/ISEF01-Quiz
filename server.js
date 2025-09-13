const express = require('express');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('.'));

console.log('🚀 Server wird gestartet...');

// Demo-Benutzer (da keine Datenbank)
const demoUsers = [
  { id: 1, username: 'demo', password: 'demo123' },
  { id: 2, username: 'testuser', password: 'test123' },
  { id: 3, username: 'paula', password: 'paula123' }
];

// API Routen
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  
  console.log(`Login-Versuch: ${username}`);
  
  // Suche in Demo-Benutzern
  const user = demoUsers.find(u => u.username === username && u.password === password);
  
  if (user) {
    console.log(`✅ Login erfolgreich: ${username}`);
    res.json({ 
      success: true, 
      user: { id: user.id, username: user.username }
    });
  } else {
    console.log(`❌ Login fehlgeschlagen: ${username}`);
    res.status(401).json({ error: 'Ungültige Anmeldedaten' });
  }
});

app.post('/api/admin/login', (req, res) => {
  const { username, password } = req.body;
  
  console.log(`Admin-Login-Versuch: ${username}`);
  
  if (username === 'admin' && password === 'admin123') {
    console.log('✅ Admin-Login erfolgreich');
    res.json({ 
      success: true, 
      user: { username: 'admin', isAdmin: true }
    });
  } else {
    console.log('❌ Admin-Login fehlgeschlagen');
    res.status(401).json({ error: 'Ungültige Admin-Anmeldedaten' });
  }
});

// Registrierung (Demo)
app.post('/api/register', (req, res) => {
  const { username, password } = req.body;
  
  // Prüfen ob Benutzer bereits existiert
  const existingUser = demoUsers.find(u => u.username === username);
  if (existingUser) {
    return res.status(400).json({ error: 'Benutzername bereits vergeben' });
  }
  
  // Neuen Benutzer hinzufügen (nur für Demo - geht bei Server-Neustart verloren)
  const newUser = {
    id: demoUsers.length + 1,
    username,
    password
  };
  demoUsers.push(newUser);
  
  console.log(`✅ Neuer Benutzer registriert: ${username}`);
  res.json({ 
    success: true, 
    user: { id: newUser.id, username: newUser.username }
  });
});

// Statische Dateien servieren
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'ISEF01_Login.html'));
});

// HTML-Dateien direkt servieren
app.get('/*.html', (req, res) => {
  const fileName = path.basename(req.path);
  const filePath = path.join(__dirname, fileName);
  
  res.sendFile(filePath, (err) => {
    if (err) {
      console.log(`❌ Datei nicht gefunden: ${fileName}`);
      res.status(404).send(`Datei ${fileName} nicht gefunden`);
    }
  });
});

// Bilder und andere Assets
app.get('*', (req, res) => {
  const filePath = path.join(__dirname, req.path);
  
  res.sendFile(filePath, (err) => {
    if (err) {
      console.log(`❌ Asset nicht gefunden: ${req.path}`);
      res.status(404).send('Asset nicht gefunden');
    }
  });
});

// Error Handler
app.use((err, req, res, next) => {
  console.error('❌ Server-Fehler:', err);
  res.status(500).json({ error: 'Interner Server-Fehler' });
});

// Server starten
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server läuft erfolgreich auf Port ${PORT}`);
  console.log(`🌐 Verfügbare Demo-Benutzer:`);
  demoUsers.forEach(user => {
    console.log(`   - ${user.username} (Passwort: ${user.password})`);
  });
  console.log(`👤 Admin: admin (Passwort: admin123)`);
  console.log(`📝 Deployment erfolgreich!`);
});