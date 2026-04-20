import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { UsersService } from '../users/users.service';
import { UserRole } from '../common/enums';

const DEFAULT_USERS = [
  { name: 'System Admin',    email: 'admin@sangemarmar.com',   password: 'Admin@1234',   role: UserRole.ADMIN },
  { name: 'Manager',         email: 'manager@sangemarmar.com', password: 'Manager@1234', role: UserRole.MANAGER },
  { name: 'Gate Operator',   email: 'gate@sangemarmar.com',    password: 'Gate@1234',    role: UserRole.GATE_OPERATOR },
  { name: 'Sales Staff',     email: 'sales@sangemarmar.com',   password: 'Sales@1234',   role: UserRole.SALES_STAFF },
  { name: 'Cashier',         email: 'cashier@sangemarmar.com', password: 'Cashier@1234', role: UserRole.CASHIER },
];

async function seed() {
  console.log('🌱 Starting seed...');

  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error'],
  });

  const usersService = app.get(UsersService);
  let created = 0;
  let skipped = 0;

  for (const u of DEFAULT_USERS) {
    const existing = await usersService.findByEmail(u.email);
    if (existing) {
      console.log(`  ⏭  Skipped (already exists): ${u.email}`);
      skipped++;
    } else {
      await usersService.create(u);
      console.log(`  ✅ Created [${u.role}]: ${u.email}  /  ${u.password}`);
      created++;
    }
  }

  console.log(`\n🏁 Done — ${created} created, ${skipped} skipped.`);

  if (created > 0) {
    console.log('\n─────────────────────────────────────────');
    console.log('  Default login credentials:');
    console.log('  admin@sangemarmar.com   /  Admin@1234');
    console.log('─────────────────────────────────────────');
  }

  await app.close();
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
