import "dotenv/config";
import express from "express";
import { GoogleGenAI } from "@google/genai";

const app = express();
const port = Number(process.env.PORT) || 3000;
const model = process.env.GEMINI_MODEL || "gemini-3.5-flash";

app.disable("x-powered-by");
app.use(express.json({ limit: "16kb" }));

app.get("/", (_request, response) => {
  response.json({ ok: true, service: "tamagotchi-chat" });
});

app.post("/chat", async (request, response) => {
  const message = request.body?.message;

  if (typeof message !== "string" || message.trim().length === 0) {
    return response.status(400).json({
      error: "message must be a non-empty string"
    });
  }

  if (message.length > 4000) {
    return response.status(413).json({
      error: "message must be 4000 characters or fewer"
    });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error("GEMINI_API_KEY is not configured");
    return response.status(503).json({
      error: "Chat service is not configured"
    });
  }

  try {
    const ai = new GoogleGenAI({ apiKey });
    const result = await ai.models.generateContent({
      model,
      contents: message.trim()
    });

    const reply = result.text?.trim();
    if (!reply) {
      throw new Error("Gemini returned an empty response");
    }

    return response.json({ reply });
  } catch (error) {
    console.error("Gemini request failed:", error?.message || error);
    return response.status(502).json({
      error: "Failed to get a response from Gemini"
    });
  }
});

app.use((error, _request, response, _next) => {
  if (error instanceof SyntaxError && error.status === 400) {
    return response.status(400).json({ error: "Invalid JSON body" });
  }

  console.error("Unhandled server error:", error);
  return response.status(500).json({ error: "Internal server error" });
});

const server = app.listen(port, "0.0.0.0", () => {
  console.log(`Tamagotchi chat server listening on port ${port}`);
});

export { app, server };
