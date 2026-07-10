require('dotenv').config();
const express = require('express');
const app = express();

app.use(express.json());

const miroRoutes = require('./routes/miro');
const trelloRoutes = require('./routes/trello');
const syncRoutes = require('./routes/sync');
const webhookRoutes = require('./routes/webhooks');

app.use('/api/miro', miroRoutes);
app.use('/api/trello', trelloRoutes);
app.use('/api/sync', syncRoutes);
app.use('/webhooks', webhookRoutes);

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    error: err.message || 'Erro interno do servidor',
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Servidor rodando na porta ${PORT}`);
});

module.exports = app;
