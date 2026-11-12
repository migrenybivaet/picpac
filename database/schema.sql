-- MySQL 8.0.16+ / 8.4. Schema proposal, not connected to the Flutter prototype.
-- Use an application account with access only to this database; never put DB credentials in an APK.
CREATE DATABASE IF NOT EXISTS picpac CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE picpac;
CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(254) NOT NULL, password_hash VARCHAR(255) NOT NULL,
  role ENUM('customer','support','admin') NOT NULL DEFAULT 'customer',
  status ENUM('active','blocked','deleted') NOT NULL DEFAULT 'active',
  full_name VARCHAR(120) NOT NULL, phone VARCHAR(32), delivery_address VARCHAR(500),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS social_links (
  user_id BIGINT UNSIGNED NOT NULL, provider VARCHAR(40) NOT NULL, url VARCHAR(2048) NOT NULL,
  PRIMARY KEY(user_id,provider), FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
-- Never store PAN, CVV or card expiry: use a PCI-compliant payment provider token later.
CREATE TABLE IF NOT EXISTS payment_methods (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, user_id BIGINT UNSIGNED NOT NULL,
  provider VARCHAR(80) NOT NULL, provider_token VARCHAR(255) NOT NULL, last4 CHAR(4) NOT NULL,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uq_provider_token(provider, provider_token)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS sessions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, user_id BIGINT UNSIGNED NOT NULL,
  token_hash BINARY(32) NOT NULL, expires_at TIMESTAMP NOT NULL, revoked_at TIMESTAMP NULL,
  UNIQUE KEY uq_token_hash(token_hash), INDEX idx_session_user(user_id),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS projects (
  id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  owner_id BIGINT UNSIGNED NOT NULL, title VARCHAR(200) NOT NULL,
  product_code VARCHAR(50) NOT NULL, settings JSON NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_projects_owner(owner_id, updated_at),
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
-- Files belong in protected storage behind an authenticated API, never public URLs.
CREATE TABLE IF NOT EXISTS project_photos (
  id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  project_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  storage_key VARCHAR(255) NOT NULL, original_name VARCHAR(255) NOT NULL,
  mime_type VARCHAR(64) NOT NULL, byte_size BIGINT UNSIGNED NOT NULL,
  width_px INT UNSIGNED NOT NULL, height_px INT UNSIGNED NOT NULL,
  sort_order INT UNSIGNED NOT NULL, edit_settings JSON NOT NULL,
  INDEX idx_project_photo_order(project_id, sort_order),
  FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS orders (
  id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL, idempotency_key CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  status ENUM('accepted','moderation','production','ready','delivered','completed','cancelled') NOT NULL DEFAULT 'accepted',
  moderation_status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  total_minor BIGINT UNSIGNED NOT NULL, currency CHAR(3) NOT NULL DEFAULT 'BYN',
  customer_snapshot JSON NOT NULL, items_snapshot JSON NOT NULL,
  payment_status ENUM('demo_pending','demo_paid','demo_failed') NOT NULL DEFAULT 'demo_pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_order_request(user_id,idempotency_key), INDEX idx_orders_user(user_id,created_at),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS order_events (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, actor_id BIGINT UNSIGNED NOT NULL,
  event_type VARCHAR(50) NOT NULL, details JSON, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_events_order(order_id,created_at),
  FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY(actor_id) REFERENCES users(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS support_threads (
  id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL, order_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  subject VARCHAR(200) NOT NULL, status ENUM('open','closed') NOT NULL DEFAULT 'open',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_threads_user(user_id,created_at),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT,
  FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE SET NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS support_messages (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, thread_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  sender_id BIGINT UNSIGNED NOT NULL, body TEXT NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_messages_thread(thread_id,created_at),
  FOREIGN KEY(thread_id) REFERENCES support_threads(id) ON DELETE CASCADE,
  FOREIGN KEY(sender_id) REFERENCES users(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS notifications (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, user_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(200) NOT NULL, body TEXT NOT NULL, read_at TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_notifications_user(user_id,created_at), FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
