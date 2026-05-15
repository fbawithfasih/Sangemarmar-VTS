// Idempotent seed for the BillingProduct catalog. Re-run any time:
//   npm run seed:billing-products
// Existing rows matched by `description` are reactivated and have their
// hsnCode / gstRate updated. New rows are inserted.
import { NestFactory } from '@nestjs/core';
import * as fs from 'fs';
import * as path from 'path';
import { AppModule } from '../app.module';
import { BillingProductsService } from '../billing-products/billing-products.service';

interface FixtureRow {
  description: string;
  hsnCode?: string;
  gstRate?: number;
}

async function seed() {
  console.log('🌱 Seeding billing-product catalog…');

  const fixturePath = path.join(__dirname, 'billing-products.fixture.json');
  const rows: FixtureRow[] = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));

  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error'],
  });
  const service = app.get(BillingProductsService);

  let created = 0;
  let updated = 0;
  const existing = await service.findAll(true);
  const byDesc = new Map(existing.map((p) => [p.description.toUpperCase(), p]));

  for (const row of rows) {
    const desc = row.description.toUpperCase();
    const before = byDesc.get(desc);
    await service.create(row);
    if (before) {
      console.log(`  ↻ Updated: ${desc}  (HSN ${row.hsnCode}, GST ${row.gstRate}%)`);
      updated++;
    } else {
      console.log(`  ✚ Created: ${desc}  (HSN ${row.hsnCode}, GST ${row.gstRate}%)`);
      created++;
    }
  }

  console.log(`\n🏁 Done — ${created} created, ${updated} updated.`);
  await app.close();
}

seed().catch((e) => {
  console.error('Seed failed:', e);
  process.exit(1);
});
