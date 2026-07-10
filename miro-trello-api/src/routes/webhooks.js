const express = require('express');
const router = express.Router();
const miro = require('../services/miro');
const trello = require('../services/trello');

/**
 * POST /webhooks/miro
 * Recebe eventos do Miro e cria/atualiza cards no Trello.
 * Configure TRELLO_DEFAULT_LIST_ID no .env para uso automático.
 *
 * Eventos suportados:
 *   - board_item_created  -> cria card no Trello
 *   - board_item_updated  -> atualiza card no Trello (se mapeado)
 */
router.post('/miro', async (req, res) => {
  try {
    const event = req.body;

    // Miro faz uma requisição GET para validar o endpoint
    if (req.method === 'GET') {
      return res.status(200).send('OK');
    }

    console.log('[Webhook Miro] Evento recebido:', JSON.stringify(event, null, 2));

    const { type, item, boardId } = event;
    const listId = process.env.TRELLO_DEFAULT_LIST_ID;

    if (!listId) {
      console.warn('[Webhook Miro] TRELLO_DEFAULT_LIST_ID não configurado');
      return res.status(200).json({ message: 'Evento recebido, mas TRELLO_DEFAULT_LIST_ID não configurado' });
    }

    if (type === 'board_item_created' && item) {
      const itemType = item.type;
      if (itemType === 'sticky_note' || itemType === 'card') {
        const name =
          itemType === 'sticky_note'
            ? (item.data && item.data.content) || 'Nota Miro'
            : (item.data && item.data.title) || 'Card Miro';

        const desc = `Criado automaticamente via Miro Webhook\nBoard: ${boardId}\nItem ID: ${item.id}`;

        await trello.createCard({ idList: listId, name, desc });
        console.log(`[Webhook Miro] Card Trello criado para item Miro ${item.id}`);
      }
    }

    res.status(200).json({ received: true });
  } catch (err) {
    console.error('[Webhook Miro] Erro:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Validação HEAD/GET do Miro para o endpoint de webhook
router.get('/miro', (req, res) => res.status(200).send('OK'));

/**
 * POST /webhooks/trello
 * Recebe eventos do Trello e cria sticky notes no Miro.
 * Configure MIRO_DEFAULT_BOARD_ID no .env para uso automático.
 *
 * Eventos suportados:
 *   - createCard  -> cria sticky note no Miro
 *   - updateCard  -> atualiza sticky note (log apenas, sem mapeamento persistido)
 */
router.post('/trello', async (req, res) => {
  try {
    const event = req.body;

    console.log('[Webhook Trello] Evento recebido:', JSON.stringify(event, null, 2));

    const action = event && event.action;
    if (!action) {
      return res.status(200).json({ received: true });
    }

    const miroBoardId = process.env.MIRO_DEFAULT_BOARD_ID;

    if (!miroBoardId) {
      console.warn('[Webhook Trello] MIRO_DEFAULT_BOARD_ID não configurado');
      return res.status(200).json({ message: 'Evento recebido, mas MIRO_DEFAULT_BOARD_ID não configurado' });
    }

    if (action.type === 'createCard') {
      const card = action.data && action.data.card;
      if (card) {
        const content = `${card.name}\nCriado via Trello - ID: ${card.id}`;
        await miro.createStickyNote(miroBoardId, { content, color: 'light_green' });
        console.log(`[Webhook Trello] Sticky note Miro criada para card Trello ${card.id}`);
      }
    }

    res.status(200).json({ received: true });
  } catch (err) {
    console.error('[Webhook Trello] Erro:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Trello faz um HEAD para validar o endpoint
router.head('/trello', (req, res) => res.status(200).send());

module.exports = router;
