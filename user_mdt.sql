CREATE TABLE `user_mdt` (
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`char_id` int(11) DEFAULT NULL,
	`notes` varchar(255) DEFAULT NULL,
	`mugshot_url` varchar(255) DEFAULT NULL,
	`bail` bit DEFAULT NULL,

	PRIMARY KEY (`id`)
);

CREATE TABLE `user_convictions` (
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`char_id` int(11) DEFAULT NULL,
	`offense` varchar(255) DEFAULT NULL,
	`count` int(11) DEFAULT NULL,
	
	PRIMARY KEY (`id`)
);

CREATE TABLE `mdt_reports` (
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`char_id` int(11) DEFAULT NULL,
	`title` varchar(255) DEFAULT NULL,
	`incident` longtext DEFAULT NULL,
    `charges` longtext DEFAULT NULL,
    `author` varchar(255) DEFAULT NULL,
	`name` varchar(255) DEFAULT NULL,
    `date` varchar(255) DEFAULT NULL,

	PRIMARY KEY (`id`)
);

CREATE TABLE `mdt_warrants` (
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`name` varchar(255) DEFAULT NULL,
	`char_id` int(11) DEFAULT NULL,
	`report_id` int(11) DEFAULT NULL,
	`report_title` varchar(255) DEFAULT NULL,
	`charges` longtext DEFAULT NULL,
	`date` varchar(255) DEFAULT NULL,
	`expire` varchar(255) DEFAULT NULL,
	`notes` varchar(255) DEFAULT NULL,
	`author` varchar(255) DEFAULT NULL,

	PRIMARY KEY (`id`)
);


CREATE TABLE `mdt_telegrams` (
	`id` int(11) NOT NULL AUTO_INCREMENT,
	`title` varchar(255) DEFAULT NULL,
	`incident` longtext DEFAULT NULL,
    `author` varchar(255) DEFAULT NULL,
    `date` varchar(255) DEFAULT NULL,

	PRIMARY KEY (`id`)
);

CREATE TABLE `mdt_fine_payments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `fine_id` int(11) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `amount` int(11) NOT NULL,
  `payment_method` enum('cash','bank') NOT NULL,
  `payment_date` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fine_id` (`fine_id`),
  KEY `citizenid` (`citizenid`),
  KEY `payment_date` (`payment_date`),
  FOREIGN KEY (`fine_id`) REFERENCES `mdt_fines`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `fine_types` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `label` VARCHAR(255) NOT NULL,
  `amount` INT(11) DEFAULT 0,
  `category` ENUM('infraction', 'misdemeanor', 'felony', 'warning') DEFAULT 'warning',
  `jailtime` INT(11) DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Inserting data for RedM fine_types table
INSERT INTO `fine_types` (`id`, `label`, `amount`, `category`, `jailtime`, `created_at`, `updated_at`) VALUES
(1, 'Aiding and Abetting', 100, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(2, 'Arson', 500, 'felony', 30, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(3, 'Stagecoach Robbery', 600, 'felony', 40, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(4, 'Attempted Murder on Sheriff/Deputy', 1500, 'felony', 60, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(5, 'Attempted Murder', 1000, 'felony', 50, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(6, 'Assault with Deadly Weapon on Sheriff/Deputy', 700, 'felony', 45, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(7, 'Assault with Deadly Weapon', 350, 'felony', 30, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(8, 'Assault on Sheriff/Deputy', 150, 'misdemeanor', 15, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(9, 'Assault', 100, 'misdemeanor', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(10, 'Bank Robbery', 800, 'felony', 50, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(11, 'Brandishing a Firearm', 100, 'misdemeanor', 5, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(12, 'Bribery', 200, 'misdemeanor', 20, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(13, 'Reckless Riding', 100, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(14, 'Corruption', 10000, 'felony', 650, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(15, 'Contempt of Court', 250, 'misdemeanor', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(16, 'Vandalism', 100, 'misdemeanor', 15, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(17, 'Dangerous Horseback Riding', 300, 'infraction', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(18, 'Damage to Town Property', 150, 'misdemeanor', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(19, 'Disturbing the Peace', 100, 'misdemeanor', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(20, 'Drunk Riding', 150, 'misdemeanor', 15, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(21, 'Moonshine Production', 550, 'felony', 40, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(22, 'Moonshine Trafficking', 500, 'felony', 40, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(23, 'Evading Sheriff', 200, 'misdemeanor', 20, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(24, 'Excessive Speeding (Horse) 4', 250, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(25, 'Excessive Speeding (Horse) 3', 200, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(26, 'Excessive Speeding (Horse) 2', 150, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(27, 'Excessive Speeding (Horse)', 100, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(28, 'Failure to Stop for Sheriff', 100, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(29, 'False Report to Sheriff', 100, 'misdemeanor', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(30, 'Refusing to Provide Identity', 150, 'misdemeanor', 15, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(31, 'Disobeying Sheriff’s Order', 150, 'misdemeanor', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(32, 'Impersonating a Sheriff/Deputy', 200, 'misdemeanor', 25, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(33, 'Attempted Felony', 350, 'felony', 20, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(34, 'Felony Drunk Riding', 300, 'felony', 30, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(35, 'Horse Theft', 300, 'felony', 20, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(36, 'Hit and Run (Horse)', 150, 'misdemeanor', 15, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(37, 'Homestead Robbery', 100, 'misdemeanor', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(38, 'Illegal Gambling', 200, 'misdemeanor', 20, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(39, 'Reckless Wagon Maneuver', 100, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(40, 'Improper Wagon Parking', 100, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(41, 'Illegal Wagon Turn', 100, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(42, 'Public Indecency', 100, 'misdemeanor', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(43, 'Incident Report', 100, 'warning', 0, '2025-08-21 16:52:01', '2025-08-21 21:05:57'),
(44, 'Involuntary Manslaughter', 10000, 'felony', 120, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(45, 'Kidnapping of Sheriff/Deputy', 400, 'felony', 40, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(46, 'Kidnapping / Hostage Taking', 200, 'felony', 20, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(47, 'Petty Theft', 150, 'misdemeanor', 20, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(48, 'Loitering in Restricted Area', 100, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(49, 'Murder', 25000, 'felony', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(50, 'Obstruction of Justice', 150, 'misdemeanor', 15, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(51, 'Blocking Town Roads', 150, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(52, 'Organizing Illegal Horse Race', 150, 'misdemeanor', 15, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(53, 'Perjury', 1000, 'felony', 60, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(54, 'Participating in Illegal Horse Race', 50, 'misdemeanor', 5, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(55, 'Possession of Moonshine', 150, 'misdemeanor', 15, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(56, 'Possession of Opium', 250, 'misdemeanor', 20, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(57, 'Possession of Illegal Firearm', 800, 'felony', 40, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(58, 'Possession of Legal Firearm Without Permit', 150, 'misdemeanor', 15, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(59, 'Possession of Stolen Money', 200, 'misdemeanor', 25, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(60, 'Possession of Stolen Goods', 100, 'misdemeanor', 15, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(61, 'Prostitution', 250, 'misdemeanor', 15, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(62, 'Public Intoxication', 100, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(63, 'Reckless Endangerment', 150, 'misdemeanor', 5, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(64, 'Resisting Arrest', 100, 'misdemeanor', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(65, 'Saloon Robbery', 150, 'misdemeanor', 15, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(66, 'Sale of Moonshine', 250, 'felony', 20, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(67, 'Sale of Opium', 400, 'felony', 30, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(68, 'Stalking', 350, 'felony', 20, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(69, 'Tampering With Evidence', 200, 'misdemeanor', 20, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(70, 'Threatening Bodily Harm', 100, 'misdemeanor', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(71, 'Terroristic Threat', 150, 'misdemeanor', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(72, 'Trespassing', 100, 'misdemeanor', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(73, 'Unlawful Discharge of Firearm', 150, 'misdemeanor', 10, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(74, 'Illegal Solicitation', 150, 'misdemeanor', 20, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(75, 'Vehicular Manslaughter (Wagon/Horse)', 7500, 'felony', 100, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(76, 'Verbal Harassment', 100, 'infraction', 0, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(77, 'Verbal Warning', 0, 'warning', 0, '2025-08-21 16:52:01', '2025-08-21 21:06:19'),
(78, 'Weapons Caching (Illegal Firearms)', 2500, 'felony', 120, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(79, 'Weapons Caching (Legal Firearms)', 1250, 'felony', 60, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(80, 'Weapons Trafficking (Illegal Firearms)', 1700, 'felony', 80, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(81, 'Weapons Trafficking (Legal Firearms)', 800, 'felony', 45, '2025-08-21 16:52:01', '2025-08-21 16:52:01'),
(82, 'Written Citation', 100, 'warning', 0, '2025-08-21 16:52:01', '2025-08-21 21:06:22');
