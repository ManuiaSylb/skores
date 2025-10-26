import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/game.dart';
import '../models/player.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('skullking.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // handle migrations from older versions to newer ones
    if (oldVersion < 2) {
      // add the new bonus detail columns if they don't exist yet
      // use try/catch to ignore errors if column already present
      try {
        await db.execute('ALTER TABLE manche_scores ADD COLUMN colored_fourteens INTEGER DEFAULT 0');
      } catch (e) {
        // ignore
      }
      try {
        await db.execute('ALTER TABLE manche_scores ADD COLUMN black_fourteen INTEGER DEFAULT 0');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE manche_scores ADD COLUMN captured_mermaids INTEGER DEFAULT 0');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE manche_scores ADD COLUMN captured_pirates INTEGER DEFAULT 0');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE manche_scores ADD COLUMN skullking_captured INTEGER DEFAULT 0');
      } catch (e) {}
      // ensure UNIQUE constraint: SQLite cannot add UNIQUE constraint to existing table easily
      // We rely on the CREATE path for new DBs. For existing DBs, duplicates won't block inserts but
      // our save method uses INSERT OR REPLACE which will replace rows only if PRIMARY KEY or unique
      // constraint exists; since adding a unique constraint to existing table is complex, recommend
      // reinstalling app to fully apply the new schema if you need the UNIQUE behavior immediately.
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE games(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        players TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE players(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE game_players(
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE,
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE manche_scores(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        manche_num INTEGER NOT NULL,
        pari INTEGER,
        plis INTEGER,
        bonus INTEGER DEFAULT 0,
        colored_fourteens INTEGER DEFAULT 0,
        black_fourteen INTEGER DEFAULT 0,
        captured_mermaids INTEGER DEFAULT 0,
        captured_pirates INTEGER DEFAULT 0,
        skullking_captured INTEGER DEFAULT 0,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE,
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE,
        UNIQUE(game_id, player_id, manche_num) ON CONFLICT REPLACE
      )
    ''');
  }

  // Games
  Future<int> insertGame(Game game) async {
    final db = await instance.database;
    return await db.insert('games', {
      'id': game.id,
      'date': game.date,
      'players': '', // Ce champ n'est plus utilisé
    });
  }

  Future<List<Game>> getAllGames() async {
    final db = await instance.database;
    final games = await db.query('games', orderBy: 'id DESC');

    List<Game> result = [];
    for (var gameMap in games) {
      final game = Game.fromMap(gameMap);
      final players = await getPlayersForGame(game.id!);
      game.players = players.map((p) => p.name).toList();
      result.add(game);
    }
    return result;
  }

  // Players
  Future<List<Player>> getAllPlayers() async {
    final db = await instance.database;
    final result = await db.query('players', orderBy: 'name');
    return result.map((json) => Player.fromMap(json)).toList();
  }

  Future<int> insertPlayer(Player player) async {
    final db = await instance.database;
    return await db.insert('players', player.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Game-Player link
  Future<void> linkPlayerToGame(int gameId, int playerId) async {
    final db = await instance.database;
    await db.insert('game_players', {
      'game_id': gameId,
      'player_id': playerId,
    });
  }

  Future<List<Player>> getPlayersForGame(int gameId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT p.id, p.name FROM players p
      INNER JOIN game_players gp ON p.id = gp.player_id
      WHERE gp.game_id = ?
      ORDER BY p.name
    ''', [gameId]);
    return result.map((e) => Player.fromMap(e)).toList();
  }

  // Manche scores
  Future<void> saveMancheScore(
    int gameId,
    int playerId,
    int mancheNum,
    Map<String, int?> data,
  ) async {
    final db = await instance.database;
    await db.insert('manche_scores', {
      'game_id': gameId,
      'player_id': playerId,
      'manche_num': mancheNum,
      'pari': data['pari'],
      'plis': data['plis'],
      'bonus': data['bonus'] ?? 0,
      'colored_fourteens': data['colored_fourteens'] ?? 0,
      'black_fourteen': data['black_fourteen'] ?? 0,
      'captured_mermaids': data['captured_mermaids'] ?? 0,
      'captured_pirates': data['captured_pirates'] ?? 0,
      'skullking_captured': data['skullking_captured'] ?? 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<int, Map<int, Map<String, int?>>>> getAllMancheScores(
    int gameId,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'manche_scores',
      where: 'game_id = ?',
      whereArgs: [gameId],
    );

    final scores = <int, Map<int, Map<String, int?>>>{};
    for (final row in result) {
      final mancheNum = row['manche_num'] as int;
      final playerId = row['player_id'] as int;

      scores.putIfAbsent(mancheNum, () => {});
      scores[mancheNum]!.putIfAbsent(playerId, () => {});

      scores[mancheNum]![playerId] = {
        'pari': row['pari'] as int?,
        'plis': row['plis'] as int?,
        'bonus': row['bonus'] as int?,
        'colored_fourteens': row['colored_fourteens'] as int?,
        'black_fourteen': row['black_fourteen'] as int?,
        'captured_mermaids': row['captured_mermaids'] as int?,
        'captured_pirates': row['captured_pirates'] as int?,
        'skullking_captured': row['skullking_captured'] as int?,
      };
    }
    return scores;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}