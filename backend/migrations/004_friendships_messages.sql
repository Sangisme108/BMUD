CREATE TABLE IF NOT EXISTS friendships (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_low_id INT NOT NULL,
  user_high_id INT NOT NULL,
  requested_by INT NOT NULL,
  status ENUM('PENDING', 'ACCEPTED', 'REJECTED') NOT NULL DEFAULT 'PENDING',
  accepted_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_friendships_low_user
    FOREIGN KEY (user_low_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_friendships_high_user
    FOREIGN KEY (user_high_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_friendships_requester
    FOREIGN KEY (requested_by) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uq_friendships_pair (user_low_id, user_high_id),
  INDEX idx_friendships_low_status (user_low_id, status),
  INDEX idx_friendships_high_status (user_high_id, status)
);

CREATE TABLE IF NOT EXISTS messages (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  sender_id INT NOT NULL,
  receiver_id INT NOT NULL,
  content VARCHAR(2000) NOT NULL,
  read_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_messages_sender
    FOREIGN KEY (sender_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_messages_receiver
    FOREIGN KEY (receiver_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_messages_pair_time (sender_id, receiver_id, id),
  INDEX idx_messages_receiver_read (receiver_id, read_at, id)
);
