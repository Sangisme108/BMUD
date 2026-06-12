const pool = require('../config/db');

const createHttpError = (message, statusCode) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
};

const parsePositiveId = (value, fieldName = 'id') => {
  const rawValue = value?.toString() ?? '';
  if (!/^\d+$/.test(rawValue)) {
    throw createHttpError(`${fieldName} không hợp lệ`, 400);
  }
  const parsed = Number.parseInt(rawValue, 10);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw createHttpError(`${fieldName} không hợp lệ`, 400);
  }
  return parsed;
};

const pairFor = (firstId, secondId) => ({
  lowId: Math.min(firstId, secondId),
  highId: Math.max(firstId, secondId),
});

const assertAcceptedFriendship = async (userId, friendId) => {
  const { lowId, highId } = pairFor(userId, friendId);
  const [[friendship]] = await pool.query(
    `SELECT id
     FROM friendships
     WHERE user_low_id = ?
       AND user_high_id = ?
       AND status = 'ACCEPTED'
     LIMIT 1`,
    [lowId, highId]
  );
  if (!friendship) {
    throw createHttpError('Chỉ có thể nhắn tin với tài khoản đã kết bạn', 403);
  }
};

const searchUsers = async (req, res, next) => {
  try {
    const query = (req.query.query || '').toString().trim();
    if (query.length < 2) {
      return res.json({ data: [] });
    }

    const likeQuery = `%${query}%`;
    const [rows] = await pool.query(
      `SELECT
         u.id,
         u.full_name,
         u.email,
         CASE
           WHEN f.id IS NULL THEN 'NONE'
           WHEN f.status = 'PENDING' AND f.requested_by = ? THEN 'OUTGOING'
           WHEN f.status = 'PENDING' THEN 'INCOMING'
           ELSE f.status
         END AS relationship_status
       FROM users u
       LEFT JOIN friendships f
         ON f.user_low_id = LEAST(?, u.id)
        AND f.user_high_id = GREATEST(?, u.id)
       WHERE u.id <> ?
         AND (u.full_name LIKE ? OR u.email LIKE ?)
       ORDER BY u.full_name ASC
       LIMIT 20`,
      [req.user.id, req.user.id, req.user.id, req.user.id, likeQuery, likeQuery]
    );
    return res.json({ data: rows });
  } catch (error) {
    return next(error);
  }
};

const sendFriendRequest = async (req, res, next) => {
  let connection;
  try {
    const targetId = parsePositiveId(req.body.user_id, 'user_id');
    if (targetId === req.user.id) {
      throw createHttpError('Không thể tự kết bạn với chính mình', 400);
    }

    connection = await pool.getConnection();
    await connection.beginTransaction();

    const [[target]] = await connection.query(
      'SELECT id FROM users WHERE id = ? LIMIT 1',
      [targetId]
    );
    if (!target) {
      throw createHttpError('Không tìm thấy tài khoản', 404);
    }

    const { lowId, highId } = pairFor(req.user.id, targetId);
    const [[existing]] = await connection.query(
      `SELECT id, status
       FROM friendships
       WHERE user_low_id = ? AND user_high_id = ?
       FOR UPDATE`,
      [lowId, highId]
    );

    if (existing?.status === 'ACCEPTED') {
      throw createHttpError('Hai tài khoản đã là bạn bè', 409);
    }
    if (existing?.status === 'PENDING') {
      throw createHttpError('Lời mời kết bạn đang chờ xử lý', 409);
    }

    if (existing) {
      await connection.query(
        `UPDATE friendships
         SET requested_by = ?, status = 'PENDING', accepted_at = NULL
         WHERE id = ?`,
        [req.user.id, existing.id]
      );
    } else {
      await connection.query(
        `INSERT INTO friendships
         (user_low_id, user_high_id, requested_by)
         VALUES (?, ?, ?)`,
        [lowId, highId, req.user.id]
      );
    }

    await connection.commit();
    return res.status(201).json({ message: 'Đã gửi lời mời kết bạn' });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
  }
};

const getFriendRequests = async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT
         f.id,
         u.id AS sender_id,
         u.full_name,
         u.email,
         f.created_at
       FROM friendships f
       JOIN users u ON u.id = f.requested_by
       WHERE f.status = 'PENDING'
         AND f.requested_by <> ?
         AND (f.user_low_id = ? OR f.user_high_id = ?)
       ORDER BY f.created_at DESC`,
      [req.user.id, req.user.id, req.user.id]
    );
    return res.json({ data: rows });
  } catch (error) {
    return next(error);
  }
};

const respondToFriendRequest = async (req, res, next) => {
  let connection;
  try {
    const requestId = parsePositiveId(req.params.id, 'request id');
    const action = (req.body.action || '').toString().toUpperCase();
    if (!['ACCEPT', 'REJECT'].includes(action)) {
      throw createHttpError('action phải là ACCEPT hoặc REJECT', 400);
    }

    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [[friendship]] = await connection.query(
      `SELECT id, user_low_id, user_high_id, requested_by, status
       FROM friendships
       WHERE id = ?
       FOR UPDATE`,
      [requestId]
    );

    const isRecipient =
      friendship &&
      friendship.requested_by !== req.user.id &&
      (friendship.user_low_id === req.user.id ||
        friendship.user_high_id === req.user.id);
    if (!isRecipient || friendship.status !== 'PENDING') {
      throw createHttpError(
        'Lời mời kết bạn không tồn tại hoặc đã được xử lý',
        404
      );
    }

    const nextStatus = action === 'ACCEPT' ? 'ACCEPTED' : 'REJECTED';
    await connection.query(
      `UPDATE friendships
       SET status = ?, accepted_at = ?
       WHERE id = ?`,
      [nextStatus, nextStatus === 'ACCEPTED' ? new Date() : null, requestId]
    );
    await connection.commit();
    return res.json({
      message:
        action === 'ACCEPT'
          ? 'Đã chấp nhận lời mời kết bạn'
          : 'Đã từ chối lời mời kết bạn',
    });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
  }
};

const getFriends = async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT
         u.id,
         u.full_name,
         u.email,
         (
           SELECT COUNT(*)
           FROM messages unread
           WHERE unread.sender_id = u.id
             AND unread.receiver_id = ?
             AND unread.read_at IS NULL
         ) AS unread_count
       FROM friendships f
       JOIN users u
         ON u.id = IF(f.user_low_id = ?, f.user_high_id, f.user_low_id)
       WHERE f.status = 'ACCEPTED'
         AND (f.user_low_id = ? OR f.user_high_id = ?)
       ORDER BY u.full_name ASC`,
      [req.user.id, req.user.id, req.user.id, req.user.id]
    );
    return res.json({ data: rows });
  } catch (error) {
    return next(error);
  }
};

const getConversations = async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      `SELECT
         u.id,
         u.full_name,
         u.email,
         (
           SELECT m.content
           FROM messages m
           WHERE (m.sender_id = ? AND m.receiver_id = u.id)
              OR (m.sender_id = u.id AND m.receiver_id = ?)
           ORDER BY m.id DESC
           LIMIT 1
         ) AS last_message,
         (
           SELECT m.created_at
           FROM messages m
           WHERE (m.sender_id = ? AND m.receiver_id = u.id)
              OR (m.sender_id = u.id AND m.receiver_id = ?)
           ORDER BY m.id DESC
           LIMIT 1
         ) AS last_message_at,
         (
           SELECT COUNT(*)
           FROM messages unread
           WHERE unread.sender_id = u.id
             AND unread.receiver_id = ?
             AND unread.read_at IS NULL
         ) AS unread_count
       FROM friendships f
       JOIN users u
         ON u.id = IF(f.user_low_id = ?, f.user_high_id, f.user_low_id)
       WHERE f.status = 'ACCEPTED'
         AND (f.user_low_id = ? OR f.user_high_id = ?)
       ORDER BY last_message_at IS NULL, last_message_at DESC, u.full_name ASC`,
      [
        req.user.id,
        req.user.id,
        req.user.id,
        req.user.id,
        req.user.id,
        req.user.id,
        req.user.id,
        req.user.id,
      ]
    );
    return res.json({ data: rows });
  } catch (error) {
    return next(error);
  }
};

const getMessages = async (req, res, next) => {
  try {
    const friendId = parsePositiveId(req.params.friendId, 'friend id');
    await assertAcceptedFriendship(req.user.id, friendId);

    const requestedLimit = Number.parseInt(req.query.limit, 10);
    const limit = Math.min(
      Number.isSafeInteger(requestedLimit) && requestedLimit > 0
        ? requestedLimit
        : 50,
      100
    );
    const beforeId = req.query.before_id
      ? parsePositiveId(req.query.before_id, 'before_id')
      : null;
    const params = [req.user.id, friendId, friendId, req.user.id];
    let beforeClause = '';
    if (beforeId) {
      beforeClause = 'AND id < ?';
      params.push(beforeId);
    }
    params.push(limit);

    const [rows] = await pool.query(
      `SELECT id, sender_id, receiver_id, content, read_at, created_at
       FROM messages
       WHERE ((sender_id = ? AND receiver_id = ?)
          OR (sender_id = ? AND receiver_id = ?))
         ${beforeClause}
       ORDER BY id DESC
       LIMIT ?`,
      params
    );

    await pool.query(
      `UPDATE messages
       SET read_at = NOW()
       WHERE sender_id = ?
         AND receiver_id = ?
         AND read_at IS NULL`,
      [friendId, req.user.id]
    );

    return res.json({ data: rows.reverse() });
  } catch (error) {
    return next(error);
  }
};

const sendMessage = async (req, res, next) => {
  try {
    const friendId = parsePositiveId(req.params.friendId, 'friend id');
    const content = (req.body.content || '').toString().trim();
    if (!content) {
      throw createHttpError('Nội dung tin nhắn không được để trống', 400);
    }
    if (content.length > 2000) {
      throw createHttpError('Tin nhắn tối đa 2000 ký tự', 400);
    }

    await assertAcceptedFriendship(req.user.id, friendId);
    const [result] = await pool.query(
      `INSERT INTO messages (sender_id, receiver_id, content)
       VALUES (?, ?, ?)`,
      [req.user.id, friendId, content]
    );
    const [[message]] = await pool.query(
      `SELECT id, sender_id, receiver_id, content, read_at, created_at
       FROM messages
       WHERE id = ?`,
      [result.insertId]
    );
    return res.status(201).json({ data: message });
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  getConversations,
  getFriendRequests,
  getFriends,
  getMessages,
  respondToFriendRequest,
  searchUsers,
  sendFriendRequest,
  sendMessage,
};
