Serverless cartoonize example (Replicate)

This file contains an example of a serverless endpoint that accepts an uploaded image, calls a hosted model (Replicate) to stylize/cartoonize it, stores the result in Supabase Storage, and returns the public URL.

Important: DO NOT commit your Replicate (or other provider) API key into source control. Use environment variables in your platform (Netlify, Vercel, Fly, etc.).

Node (Express) example

```js
// replicate_cartoonize_example.js
// install: npm i node-fetch form-data

const express = require('express');
const fetch = require('node-fetch');
const FormData = require('form-data');
const multer = require('multer');
const upload = multer();

const REPLICATE_API_TOKEN = process.env.REPLICATE_API_TOKEN; // set in env
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY; // use service role on server

const app = express();

app.post('/cartoonize', upload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'no file' });

  // Send file to Replicate (API usage depends on the model you pick)
  // Example pseudo-flow — adapt to the model's API and input shape
  const form = new FormData();
  form.append('file', req.file.buffer, { filename: req.file.originalname });

  const r = await fetch('https://api.replicate.com/v1/predictions', {
    method: 'POST',
    headers: {
      Authorization: `Token ${REPLICATE_API_TOKEN}`,
    },
    body: form,
  });

  const json = await r.json();
  // Wait for prediction to finish (replicate returns a prediction resource you poll)

  // After result ready, download stylized image and upload to Supabase Storage
  // Use the Supabase JS server library or direct Storage REST API with service key

  res.json({ publicUrl: '<url-to-stylized-image>' });
});

module.exports = app;
```

Notes and alternatives
- Replicate, Stability.ai, and other providers differ on API shape. Read their docs for "image-to-image" or "cartoonize" model usage.
- Keep API keys secret and use a serverless function or small backend to call the model.
- The server should check file size and mime type and enforce rate limits to avoid high costs.

If you'd like, I can scaffold a Vercel/Netlify function for this repo and wire the frontend to call it with a simple `fetch('/.netlify/functions/cartoonize', { method: 'POST', body: formData })` flow. Provide provider preference (Netlify, Vercel, or plain Express) and I'll generate the code and deployment notes.