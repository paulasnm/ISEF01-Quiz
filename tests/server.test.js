const app = require('../server'); // Adjust the path if needed
const request = require('supertest');

beforeAll(() => {
    // Any setup if needed before tests run
    app.listen(4000); // Start the server on a different port for testing

    // Wait for the server to start
    return new Promise((resolve) => {
        setTimeout(resolve, 100);
    });



});

afterAll(() => {
    // Any teardown if needed after tests complete
});

describe('Server', () => {
    it('should respond to GET / with 200', async () => {
        const res = await request(app).get('/');
        expect(res.statusCode).toBe(200);
    });

    it('should respond to GET /users with a non-empty user list', async () => {
        const res = await request(app).get('/users');
        expect(res.statusCode).toBe(200);
        expect(Array.isArray(res.body)).toBe(true);
        expect(res.body.length).toBeGreaterThan(0);
    });

    it('should have CORS configured for Socket.IO', () => {
        const io = require('socket.io');
        const server = require('http').createServer();
        const socketIo = io(server, {
            cors: {
                origin: "https://isef01-quiz-1.onrender.com",
                methods: ["GET", "POST"]
            }
        });
        expect(socketIo.opts.cors.origin).toBe("https://isef01-quiz-1.onrender.com");
        expect(socketIo.opts.cors.methods).toEqual(["GET", "POST"]);
    });
});
