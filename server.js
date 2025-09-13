const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Basic Middleware
app.use(express.json());
app.use(express.static('.'));

console.log('🔧 Server startet - Debug Modus');

// Demo-Benutzer
const users = [
  { id: 1, username: 'demo', password: 'demo123' },
  { id: 2, username: 'admin', password: 'admin123' }
];

// Test Route
app.get('/', (req, res) => {
  console.log('📍 Root-Route aufgerufen');
  try {
    // Versuche verschiedene HTML-Dateien zu finden
    const possibleFiles = [
      'ISEF01_Login.html',
      'index.html', 
      'login.html'
    ];
    
    // Liste alle Dateien im Verzeichnis
    const fs = require('fs');
    const files = fs.readdirSync('.');
    console.log('📁 Verfügbare Dateien:', files);
    
    // Suche nach HTML-Dateien
    const htmlFiles = files.filter(f => f.endsWith('.html'));
    console.log('🌐 HTML-Dateien gefunden:', htmlFiles);
    
    if (htmlFiles.length > 0) {
      const firstHtml = htmlFiles[0];
      console.log(`✅ Verwende: ${firstHtml}`);
      res.sendFile(path.join(__dirname, firstHtml));
    } else {
      // Fallback HTML
      res.send(`
        <html>
        <head><title>Schatzinsel Quiz - Debug</title></head>
        <body>
          <h1>🏴‍☠️ Schatzinsel Quiz</h1>
          <p><strong>Server läuft!</strong></p>
          <p>Verfügbare HTML-Dateien: ${htmlFiles.join(', ') || 'Keine gefunden'}</p>
          <p>Alle Dateien: ${files.join(', ')}</p>
          <hr>
          <h2>Login testen:</h2>
          <form id="testForm">
            <input type="text" id="user" placeholder="Benutzername" value="demo">
            <input type="password" id="pass" placeholder="Passwort" value="demo123">
            <button type="button" onclick="testLogin()">Login testen</button>
          </form>
          <div id="result"></div>
          
          <script>
          async function testLogin() {
            const user = document.getElementById('user').value;
            const pass = document.getElementById('pass').value;
            
            try {
              const response = await fetch('/api/login', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({username: user, password: pass})
              });
              const result = await response.json();
              document.getElementById('result').innerHTML = 
                '<pre>' + JSON.stringify(result, null, 2) + '</pre>';
            } catch(e) {
              document.getElementById('result').innerHTML = 'Fehler: ' + e.message;
            }
          }
          </script>
        </body>
        </html>
      `);
    }
  } catch (error) {
    console.error('❌ Fehler in Root-Route:', error);
    res.status(500).send('Server-Fehler: ' + error.message);
  }
});

// Login API
app.post('/api/login', (req, res) => {
  console.log('🔑 Login-Anfrage erhalten');
  try {
    const { username, password } = req.body;
    console.log(`👤 Login-Versuch: ${username}`);
    
    const user = users.find(u => u.username === username && u.password === password);
    
    if (user) {
      console.log(`✅ Login erfolgreich: ${username}`);
      if (username === 'admin') {
        res.json({ success: true, user: { username, isAdmin: true } });
      } else {
        res.json({ success: true, user: { id: user.id, username } });
      }
    } else {
      console.log(`❌ Login fehlgeschlagen: ${username}`);
      res.status(401).json({ error: 'Ungültige Anmeldedaten' });
    }
  } catch (error) {
    console.error('❌ Login-API Fehler:', error);
    res.status(500).json({ error: 'Login-Server-Fehler: ' + error.message });
  }
});

// Admin Login API
app.post('/api/admin/login', (req, res) => {
  console.log('👑 Admin-Login-Anfrage erhalten');
  try {
    const { username, password } = req.body;
    
    if (username === 'admin' && password === 'admin123') {
      console.log('✅ Admin-Login erfolgreich');
      res.json({ success: true, user: { username: 'admin', isAdmin: true }});
    } else {
      console.log('❌ Admin-Login fehlgeschlagen');
      res.status(401).json({ error: 'Ungültige Admin-Anmeldedaten' });
    }
  } catch (error) {
    console.error('❌ Admin-Login Fehler:', error);
    res.status(500).json({ error: 'Admin-Login-Fehler: ' + error.message });
  }
});

// Catch-all für statische Dateien
app.get('*', (req, res) => {
  console.log(`📁 Datei angefragt: ${req.path}`);
  const filePath = path.join(__dirname, req.path);
  res.sendFile(filePath, (err) => {
    if (err) {
      console.log(`❌ Datei nicht gefunden: ${req.path}`);
      res.status(404).send(`Datei nicht gefunden: ${req.path}`);
    }
  });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('💥 Unerwarteter Fehler:', err);
  res.status(500).json({ 
    error: 'Unerwarteter Server-Fehler', 
    message: err.message,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
  });
});

// Server starten
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Debug-Server läuft auf Port ${PORT}`);
  console.log(`📋 Verfügbare Login-Daten:`);
  console.log(`   👤 demo / demo123`);
  console.log(`   👑 admin / admin123`);
  console.log(`🔍 Debug-Modus aktiviert - schaue in die Logs!`);
});

// Unhandled Promise Rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('💥 Unhandled Promise Rejection:', reason);
});

// Uncaught Exceptions  
process.on('uncaughtException', (error) => {
  console.error('💥 Uncaught Exception:', error);
  process.exit(1);
});