const axios = require('axios');

const BASE_URL = 'https://api.trello.com/1';

function auth() {
  return {
    key: process.env.TRELLO_API_KEY,
    token: process.env.TRELLO_TOKEN,
  };
}

function client() {
  return axios.create({
    baseURL: BASE_URL,
    params: auth(),
  });
}

async function getBoards() {
  const res = await client().get('/members/me/boards', {
    params: { ...auth(), fields: 'id,name,url,desc,closed' },
  });
  return res.data;
}

async function getBoard(boardId) {
  const res = await client().get(`/boards/${boardId}`, {
    params: { ...auth(), fields: 'id,name,url,desc' },
  });
  return res.data;
}

async function getLists(boardId) {
  const res = await client().get(`/boards/${boardId}/lists`, {
    params: { ...auth(), fields: 'id,name,pos,closed' },
  });
  return res.data;
}

async function getCards(boardId) {
  const res = await client().get(`/boards/${boardId}/cards`, {
    params: {
      ...auth(),
      fields: 'id,name,desc,url,idList,labels,due,closed',
    },
  });
  return res.data;
}

async function getCard(cardId) {
  const res = await client().get(`/cards/${cardId}`, {
    params: { ...auth(), fields: 'id,name,desc,url,idList,labels,due,closed' },
  });
  return res.data;
}

async function createCard({ idList, name, desc = '', due = null, urlSource = null }) {
  const params = { ...auth(), idList, name, desc };
  if (due) params.due = due;
  if (urlSource) params.urlSource = urlSource;

  const res = await client().post('/cards', null, { params });
  return res.data;
}

async function updateCard(cardId, { name, desc, idList, due, closed }) {
  const params = { ...auth() };
  if (name !== undefined) params.name = name;
  if (desc !== undefined) params.desc = desc;
  if (idList !== undefined) params.idList = idList;
  if (due !== undefined) params.due = due;
  if (closed !== undefined) params.closed = closed;

  const res = await client().put(`/cards/${cardId}`, null, { params });
  return res.data;
}

async function deleteCard(cardId) {
  await client().delete(`/cards/${cardId}`, { params: auth() });
}

async function createList(boardId, name, pos = 'bottom') {
  const res = await client().post('/lists', null, {
    params: { ...auth(), idBoard: boardId, name, pos },
  });
  return res.data;
}

async function createWebhook(idModel, callbackURL, description = 'Miro-Trello Webhook') {
  const res = await client().post('/webhooks', null, {
    params: { ...auth(), idModel, callbackURL, description },
  });
  return res.data;
}

async function deleteWebhook(webhookId) {
  await client().delete(`/webhooks/${webhookId}`, { params: auth() });
}

module.exports = {
  getBoards,
  getBoard,
  getLists,
  getCards,
  getCard,
  createCard,
  updateCard,
  deleteCard,
  createList,
  createWebhook,
  deleteWebhook,
};
