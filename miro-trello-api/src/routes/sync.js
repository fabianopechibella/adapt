const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const miro = require('../services/miro');
const trello = require('../services/trello');

function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
}

/**
 * POST /api/sync/miro-to-trello
 * Sincroniza sticky notes e cards do Miro para listas do Trello.
 * Body:
 *   miroBoardId  - ID do quadro Miro
 *   trelloBoardId - ID do quadro Trello
 *   trelloListId  - ID da lista Trello de destino
 *   itemType      - (opcional) "sticky_note" | "card" | null para ambos
 */
router.post(
  '/miro-to-trello',
  [
    body('miroBoardId').notEmpty().withMessage('miroBoardId é obrigatório'),
    body('trelloListId').notEmpty().withMessage('trelloListId é obrigatório'),
    body('itemType').optional().isIn(['sticky_note', 'card']),
  ],
  validate,
  async (req, res, next) => {
    try {
      const { miroBoardId, trelloListId, itemType } = req.body;

      const miroData = await miro.getBoardItems(miroBoardId, itemType || null);
      const items = miroData.data || [];

      const results = [];
      const errors = [];

      for (const item of items) {
        const type = item.type;
        if (type !== 'sticky_note' && type !== 'card') continue;

        const name =
          type === 'sticky_note'
            ? (item.data && item.data.content) || 'Nota Miro'
            : (item.data && item.data.title) || 'Card Miro';

        const desc =
          type === 'card' && item.data && item.data.description
            ? item.data.description
            : `Importado do Miro - ID: ${item.id}`;

        try {
          const trelloCard = await trello.createCard({
            idList: trelloListId,
            name,
            desc,
          });
          results.push({ miroItemId: item.id, trelloCardId: trelloCard.id, name });
        } catch (err) {
          errors.push({ miroItemId: item.id, error: err.message });
        }
      }

      res.json({
        synced: results.length,
        failed: errors.length,
        results,
        errors,
      });
    } catch (err) {
      next(err);
    }
  }
);

/**
 * POST /api/sync/trello-to-miro
 * Sincroniza cards do Trello para sticky notes no Miro.
 * Body:
 *   trelloBoardId - ID do quadro Trello
 *   miroBoardId   - ID do quadro Miro de destino
 *   trelloListId  - (opcional) Filtra por lista específica
 *   color         - (opcional) Cor das sticky notes (default: "yellow")
 */
router.post(
  '/trello-to-miro',
  [
    body('trelloBoardId').notEmpty().withMessage('trelloBoardId é obrigatório'),
    body('miroBoardId').notEmpty().withMessage('miroBoardId é obrigatório'),
    body('trelloListId').optional().isString(),
    body('color').optional().isString(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const { trelloBoardId, miroBoardId, trelloListId, color = 'yellow' } = req.body;

      let cards = await trello.getCards(trelloBoardId);

      if (trelloListId) {
        cards = cards.filter((c) => c.idList === trelloListId);
      }

      const results = [];
      const errors = [];
      let offsetX = 0;
      let offsetY = 0;

      for (const card of cards) {
        const content = card.desc
          ? `**${card.name}**\n${card.desc}`
          : card.name;

        try {
          const note = await miro.createStickyNote(miroBoardId, {
            content,
            color,
            x: offsetX,
            y: offsetY,
          });
          results.push({ trelloCardId: card.id, miroItemId: note.id, name: card.name });
          offsetX += 250;
          if (offsetX > 1500) {
            offsetX = 0;
            offsetY += 300;
          }
        } catch (err) {
          errors.push({ trelloCardId: card.id, error: err.message });
        }
      }

      res.json({
        synced: results.length,
        failed: errors.length,
        results,
        errors,
      });
    } catch (err) {
      next(err);
    }
  }
);

module.exports = router;
