import { config } from 'dotenv';
import { DataSource } from 'typeorm';
import { buildTypeOrmOptions } from './typeorm-options';

// Entry point for the TypeORM CLI (npm run migration:*). Reads the same
// environment variables as the app.
config();

export default new DataSource(buildTypeOrmOptions((key) => process.env[key] || undefined));
