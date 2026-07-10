const express = require('express');
const router = express.Router();
const { param, body, validationResult } = require('express-validator');
const trello = require('../services/trello');

function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
}

// GET /api/trello/boards
router.get('/boards', async (req, res, next) => {
  try {
    const data = await trello.getBoards();
    res.json(data);
  } catch (err) {
    next(err);
  }
});

// GET /api/trello/boards/:boardId
router.get('/boards/:boardId', [param('boardId').notEmpty()], validate, async (req, res, next) => {
  try {
    const data = await trello.getBoard(req.params.boardId);
    res.json(data);
  } catch (err) {
    next(err);
  }
});

// GET /api/trello/boards/:boardId/lists
router.get(
  '/boards/:boardId/lists',
  [param('boardId').notEmpty()],
  validate,
  async (req, res, next) => {
    try {
      const data = await trello.getLists(req.params.boardId);
      res.json(data);
    } catch (err) {
      next(err);
    }
  }
);

// GET /api/trello/boards/:boardId/cards
router.get(
  '/boards/:boardId/cards',
  [param('boardId').notEmpty()],
  validate,
  async (req, res, next) => {
    try {
      const data = await trello.getCards(req.params.boardId);
      res.json(data);
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/trello/cards
router.post(
  '/cards',
  [
    body('idList').notEmpty().withMessage('idList é obrigatório'),
    body('name').notEmpty().withMessage('name é obrigatório'),
    body('desc').optional().isString(),
    body('due').optional().isISO8601(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const card = await trello.createCard(req.body);
      res.status(201).json(card);
    } catch (err) {
      next(err);
    }
  }
);

// PUT /api/trello/cards/:cardId
router.put(
  '/cards/:cardId',
  [param('cardId').notEmpty()],
  validate,
  async (req, res, next) => {
    try {
      const card = await trello.updateCard(req.params.cardId, req.body);
      res.json(card);
    } catch (err) {
      next(err);
    }
  }
);

// DELETE /api/trello/cards/:cardId
router.delete(
  '/cards/:cardId',
  [param('cardId').notEmpty()],
  validate,
  async (req, res, next) => {
    try {
      await trello.deleteCard(req.params.cardId);
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/trello/boards/:boardId/lists
router.post(
  '/boards/:boardId/lists',
  [
    param('boardId').notEmpty(),
    body('name').notEmpty().withMessage('name é obrigatório'),
  ],
  validate,
  async (req, res, next) => {
    try {
      const list = await trello.createList(req.params.boardId, req.body.name, req.body.pos);
      res.status(201).json(list);
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/trello/webhooks
router.post(
  '/webhooks',
  [
    body('idModel').notEmpty().withMessage('idModel é obrigatório'),
    body('callbackURL').notEmpty().isURL().withMessage('callbackURL é obrigatório e deve ser uma URL válida'),
    body('description').optional().isString(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const webhook = await trello.createWebhook(
        req.body.idModel,
        req.body.callbackURL,
        req.body.description
      );
      res.status(201).json(webhook);
    } catch (err) {
      next(err);
    }
  }
);

module.exports = router;
