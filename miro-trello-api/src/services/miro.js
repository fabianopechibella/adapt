const axios = require('axios');

const BASE_URL = 'https://api.miro.com/v2';

function client() {
  return axios.create({
    baseURL: BASE_URL,
    headers: {
      Authorization: `Bearer ${process.env.MIRO_ACCESS_TOKEN}`,
      'Content-Type': 'application/json',
    },
  });
}

async function getBoards() {
  const res = await client().get('/boards');
  return res.data;
}

async function getBoardItems(boardId, type = null) {
  const params = type ? { type } : {};
  const res = await client().get(`/boards/${boardId}/items`, { params });
  return res.data;
}

async function getItem(boardId, itemId) {
  const res = await client().get(`/boards/${boardId}/items/${itemId}`);
  return res.data;
}

async function createStickyNote(boardId, { content, color = 'yellow', x = 0, y = 0 }) {
  const res = await client().post(`/boards/${boardId}/sticky_notes`, {
    data: { content, shape: 'square' },
    style: { fillColor: color },
    position: { x, y },
  });
  return res.data;
}

async function updateStickyNote(boardId, itemId, { content, color }) {
  const body = {};
  if (content !== undefined) body.data = { content };
  if (color !== undefined) body.style = { fillColor: color };

  const res = await client().patch(`/boards/${boardId}/sticky_notes/${itemId}`, body);
  return res.data;
}

async function deleteStickyNote(boardId, itemId) {
  await client().delete(`/boards/${boardId}/sticky_notes/${itemId}`);
}

async function createCard(boardId, { title, description = '', x = 0, y = 0 }) {
  const res = await client().post(`/boards/${boardId}/cards`, {
    data: { title, description },
    position: { x, y },
  });
  return res.data;
}

async function updateCard(boardId, cardId, { title, description }) {
  const body = { data: {} };
  if (title !== undefined) body.data.title = title;
  if (description !== undefined) body.data.description = description;

  const res = await client().patch(`/boards/${boardId}/cards/${cardId}`, body);
  return res.data;
}

async function deleteCard(boardId, cardId) {
  await client().delete(`/boards/${boardId}/cards/${cardId}`);
}

async function createWebhook(boardId, callbackUrl) {
  const res = await client().post('/webhooks/board_subscriptions', {
    boardId,
    callbackUrl,
  });
  return res.data;
}

async function deleteWebhook(webhookId) {
  await client().delete(`/webhooks/board_subscriptions/${webhookId}`);
}

module.exports = {
  getBoards,
  getBoardItems,
  getItem,
  createStickyNote,
  updateStickyNote,
  deleteStickyNote,
  createCard,
  updateCard,
  deleteCard,
  createWebhook,
  deleteWebhook,
};
