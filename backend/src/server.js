'use strict';

require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');

const app = express();
const port = Number(process.env.PORT || 10000);
const allowedOrigin = process.env.CORS_ORIGIN || '*';
app.disable('x-powered-by');
app.use(helmet());
app.use(cors({ origin: allowedOrigin === '*' ? true : allowedOrigin.split(',').map(v => v.trim()) }));
app.use(express.json({ limit: '1mb' }));

let supabase = null;
if (process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY) {
  supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false }
  });
}

app.get('/health', (_req, res) => res.status(200).json({
  ok: true,
  service: 'kawn-library-api',
  version: '0.1.0',
  databaseConfigured: Boolean(supabase)
}));

app.get('/api/v1/books', async (req, res) => {
  if (!supabase) return res.status(503).json({ error: 'DATABASE_NOT_CONFIGURED' });
  const limit = Math.min(Math.max(Number.parseInt(req.query.limit || '20', 10) || 20, 1), 50);
  const { data, error } = await supabase
    .from('books')
    .select('id,title,description,language,cover_path,created_at')
    .eq('publication_status', 'published')
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) return res.status(500).json({ error: 'BOOKS_FETCH_FAILED' });
  return res.json({ data });
});

app.use((err, _req, res, _next) => {
  console.error('Unhandled request error:', err.message);
  res.status(500).json({ error: 'INTERNAL_SERVER_ERROR' });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Kawn Library API listening on ${port}`);
});
