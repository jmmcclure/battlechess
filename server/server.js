const { WebSocketServer } = require("ws");
const crypto = require("crypto");

const PORT = process.env.PORT || 8080;
const wss = new WebSocketServer({ port: PORT });

/** @type {Map<string, Lobby>} */
const lobbies = new Map();

class Lobby {
  constructor(code, host) {
    this.code = code;
    this.host = host; // ws connection
    this.guest = null;
    this.hostName = "Player 1";
    this.guestName = "Player 2";
    this.hostColor = Math.random() < 0.5 ? 0 : 1;
    this.state = "waiting"; // waiting, playing, finished
    this.moves = [];
    this.createdAt = Date.now();
  }

  isFull() {
    return this.host && this.guest;
  }

  getOpponent(ws) {
    return ws === this.host ? this.guest : this.host;
  }

  getColor(ws) {
    return ws === this.host ? this.hostColor : 1 - this.hostColor;
  }
}

function generateCode() {
  return crypto.randomBytes(3).toString("hex").toUpperCase();
}

function send(ws, data) {
  if (ws && ws.readyState === 1) {
    ws.send(JSON.stringify(data));
  }
}

wss.on("connection", (ws) => {
  ws._lobby = null;

  ws.on("message", (raw) => {
    let data;
    try {
      data = JSON.parse(raw.toString());
    } catch {
      send(ws, { type: "error", message: "Invalid JSON" });
      return;
    }

    switch (data.type) {
      case "create_lobby": {
        // Clean up any existing lobby membership
        leaveLobby(ws);

        let code;
        do {
          code = generateCode();
        } while (lobbies.has(code));

        const lobby = new Lobby(code, ws);
        lobby.hostName = data.player_name || "Player 1";
        lobbies.set(code, lobby);
        ws._lobby = lobby;

        send(ws, {
          type: "lobby_created",
          code,
          color: lobby.hostColor,
        });
        console.log(`Lobby ${code} created by ${lobby.hostName}`);
        break;
      }

      case "join_lobby": {
        const code = (data.code || "").toUpperCase();
        const lobby = lobbies.get(code);

        if (!lobby) {
          send(ws, { type: "error", message: "Lobby not found" });
          return;
        }
        if (lobby.isFull()) {
          send(ws, { type: "error", message: "Lobby is full" });
          return;
        }

        leaveLobby(ws);
        lobby.guest = ws;
        lobby.guestName = data.player_name || "Player 2";
        lobby.state = "playing";
        ws._lobby = lobby;

        send(ws, {
          type: "lobby_joined",
          code,
          color: 1 - lobby.hostColor,
        });

        // Notify both players
        send(lobby.host, {
          type: "opponent_connected",
          name: lobby.guestName,
          color: lobby.hostColor,
        });
        send(lobby.guest, {
          type: "opponent_connected",
          name: lobby.hostName,
          color: 1 - lobby.hostColor,
        });

        console.log(`${lobby.guestName} joined lobby ${code}`);
        break;
      }

      case "move": {
        const lobby = ws._lobby;
        if (!lobby || lobby.state !== "playing") {
          send(ws, { type: "error", message: "Not in a game" });
          return;
        }
        const opponent = lobby.getOpponent(ws);
        lobby.moves.push({
          from: data.from,
          to: data.to,
          flags: data.flags || 0,
          color: lobby.getColor(ws),
          timestamp: Date.now(),
        });
        send(opponent, {
          type: "move",
          from: data.from,
          to: data.to,
          flags: data.flags || 0,
        });
        break;
      }

      case "resign": {
        const lobby = ws._lobby;
        if (!lobby) return;
        const opponent = lobby.getOpponent(ws);
        lobby.state = "finished";
        send(opponent, {
          type: "opponent_resigned",
          winner: lobby.getColor(opponent),
        });
        send(ws, {
          type: "you_resigned",
          winner: lobby.getColor(opponent),
        });
        break;
      }

      case "draw_offer": {
        const lobby = ws._lobby;
        if (!lobby) return;
        send(lobby.getOpponent(ws), { type: "draw_offered" });
        break;
      }

      case "draw_accept": {
        const lobby = ws._lobby;
        if (!lobby) return;
        lobby.state = "finished";
        send(lobby.host, { type: "draw_accepted" });
        send(lobby.guest, { type: "draw_accepted" });
        break;
      }

      case "draw_decline": {
        const lobby = ws._lobby;
        if (!lobby) return;
        send(lobby.getOpponent(ws), { type: "draw_declined" });
        break;
      }

      case "rematch": {
        const lobby = ws._lobby;
        if (!lobby) return;
        const opponent = lobby.getOpponent(ws);
        if (!ws._rematchRequested) {
          ws._rematchRequested = true;
          send(opponent, { type: "rematch_requested" });
        }
        // If both requested, start new game
        if (opponent._rematchRequested) {
          lobby.hostColor = 1 - lobby.hostColor; // swap colors
          lobby.state = "playing";
          lobby.moves = [];
          ws._rematchRequested = false;
          opponent._rematchRequested = false;

          send(lobby.host, {
            type: "rematch_accepted",
            color: lobby.hostColor,
          });
          send(lobby.guest, {
            type: "rematch_accepted",
            color: 1 - lobby.hostColor,
          });
        }
        break;
      }

      case "chat": {
        const lobby = ws._lobby;
        if (!lobby) return;
        const opponent = lobby.getOpponent(ws);
        const playerName =
          ws === lobby.host ? lobby.hostName : lobby.guestName;
        send(opponent, {
          type: "chat",
          message: data.message || "",
          from: playerName,
        });
        break;
      }

      default:
        send(ws, { type: "error", message: `Unknown type: ${data.type}` });
    }
  });

  ws.on("close", () => {
    leaveLobby(ws);
  });

  ws.on("error", (err) => {
    console.error("WebSocket error:", err.message);
    leaveLobby(ws);
  });
});

function leaveLobby(ws) {
  const lobby = ws._lobby;
  if (!lobby) return;

  const opponent = lobby.getOpponent(ws);
  if (opponent) {
    send(opponent, { type: "opponent_disconnected" });
  }

  // Clean up lobby if empty
  if (ws === lobby.host) {
    lobby.host = null;
  } else {
    lobby.guest = null;
  }

  if (!lobby.host && !lobby.guest) {
    lobbies.delete(lobby.code);
    console.log(`Lobby ${lobby.code} removed (empty)`);
  }

  ws._lobby = null;
}

// Periodic cleanup of stale lobbies (older than 2 hours)
setInterval(() => {
  const cutoff = Date.now() - 2 * 60 * 60 * 1000;
  for (const [code, lobby] of lobbies) {
    if (lobby.createdAt < cutoff && lobby.state !== "playing") {
      if (lobby.host) send(lobby.host, { type: "lobby_expired" });
      if (lobby.guest) send(lobby.guest, { type: "lobby_expired" });
      lobbies.delete(code);
      console.log(`Lobby ${code} expired`);
    }
  }
}, 60000);

console.log(`Battle Chess WebSocket server running on port ${PORT}`);
console.log("Waiting for connections...");
