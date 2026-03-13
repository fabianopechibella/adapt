const express = require('express');
const router = express.Router();
const { param, query, body, validationResult } = require('express-validator');
const miro = require('../services/miro');

function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
}

// GET /api/miro/boards
router.get('/boards', async (req, res, next) => {
  try {
    const data = await miro.getBoards();
    res.json(data);
  } catch (err) {
    next(err);
  }
});

// GET /api/miro/boards/:boardId/items
router.get(
  '/boards/:boardId/items',
  [param('boardId').notEmpty(), query('type').optional().isString()],
  validate,
  async (req, res, next) => {
    try {
      const data = await miro.getBoardItems(req.params.boardId, req.query.type);
      res.json(data);
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/miro/boards/:boardId/sticky_notes
router.post(
  '/boards/:boardId/sticky_notes',
  [
    param('boardId').notEmpty(),
    body('content').notEmpty().withMessage('content é obrigatório'),
    body('color').optional().isString(),
    body('x').optional().isNumeric(),
    body('y').optional().isNumeric(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const item = await miro.createStickyNote(req.params.boardId, req.body);
      res.status(201).json(item);
    } catch (err) {
      next(err);
    }
  }
);

// PATCH /api/miro/boards/:boardId/sticky_notes/:itemId
router.patch(
  '/boards/:boardId/sticky_notes/:itemId',
  [param('boardId').notEmpty(), param('itemId').notEmpty()],
  validate,
  async (req, res, next) => {
    try {
      const item = await miro.updateStickyNote(
        req.params.boardId,
        req.params.itemId,
        req.body
      );
      res.json(item);
    } catch (err) {
      next(err);
    }
  }
);

// DELETE /api/miro/boards/:boardId/sticky_notes/:itemId
router.delete(
  '/boards/:boardId/sticky_notes/:itemId',
  [param('boardId').notEmpty(), param('itemId').notEmpty()],
  validate,
  async (req, res, next) => {
    try {
      await miro.deleteStickyNote(req.params.boardId, req.params.itemId);
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/miro/boards/:boardId/cards
router.post(
  '/boards/:boardId/cards',
  [
    param('boardId').notEmpty(),
    body('title').notEmpty().withMessage('title é obrigatório'),
    body('description').optional().isString(),
    body('x').optional().isNumeric(),
    body('y').optional().isNumeric(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const item = await miro.createCard(req.params.boardId, req.body);
      res.status(201).json(item);
    } catch (err) {
      next(err);
    }
  }
);

// POST /api/miro/boards/:boardId/webhooks
router.post(
  '/boards/:boardId/webhooks',
  [
    param('boardId').notEmpty(),
    body('callbackUrl').notEmpty().isURL().withMessage('callbackUrl é obrigatório e deve ser uma URL válida'),
  ],
  validate,
  async (req, res, next) => {
    try {
      const webhook = await miro.createWebhook(req.params.boardId, req.body.callbackUrl);
      res.status(201).json(webhook);
    } catch (err) {
      next(err);
    }
  }
);

module.exports = router;
