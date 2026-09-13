import { MigrationInterface, QueryRunner } from "typeorm";

export class InitialSchema1789315823439 implements MigrationInterface {
    name = 'InitialSchema1789315823439'

    public async up(queryRunner: QueryRunner): Promise<void> {
        // Baseline of the schema that TypeORM `synchronize` had built before
        // migrations were introduced. Existing databases (production) already
        // have it, so the migration is only recorded as applied there.
        if (await queryRunner.hasTable('users')) return;

        await queryRunner.query(`CREATE TYPE "public"."users_role_enum" AS ENUM('ADMIN', 'MANAGER', 'GATE_OPERATOR', 'SALES_STAFF', 'CASHIER')`);
        await queryRunner.query(`CREATE TABLE "users" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "name" character varying NOT NULL, "email" character varying NOT NULL, "password" character varying NOT NULL, "role" "public"."users_role_enum" NOT NULL DEFAULT 'GATE_OPERATOR', "isActive" boolean NOT NULL DEFAULT true, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_97672ac88f789774dd47f7c8be3" UNIQUE ("email"), CONSTRAINT "PK_a3ffb1c0c8416b9fc6f907b7433" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."vehicle_entries_status_enum" AS ENUM('ENTERED', 'SALES_PENDING', 'SALES_COMPLETE', 'PAYMENT_PENDING', 'PAYMENT_COMPLETE', 'COMMISSION_PENDING', 'COMMISSION_COMPLETE', 'COMPLETED', 'NO_SALE')`);
        await queryRunner.query(`CREATE TABLE "vehicle_entries" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "vehicleNumber" character varying NOT NULL, "driverName" character varying NOT NULL, "driverMobile" character varying, "guideName" character varying NOT NULL, "guideMobile" character varying, "localAgent" character varying NOT NULL, "companyName" character varying NOT NULL, "entryDate" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(), "status" "public"."vehicle_entries_status_enum" NOT NULL DEFAULT 'ENTERED', "notes" character varying, "createdById" uuid, "assignedSalesmanId" uuid, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_8c864f222605db03aeffa03269c" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_e2c39fbcc81942d651b9ab023f" ON "vehicle_entries" ("vehicleNumber") `);
        await queryRunner.query(`CREATE INDEX "IDX_ab4cbac9d722c3f229d3de2c51" ON "vehicle_entries" ("driverName") `);
        await queryRunner.query(`CREATE INDEX "IDX_5b84c2372a5038a0b155c3bccd" ON "vehicle_entries" ("guideName") `);
        await queryRunner.query(`CREATE INDEX "IDX_c4c0bcb0eee3185854a933686a" ON "vehicle_entries" ("localAgent") `);
        await queryRunner.query(`CREATE INDEX "IDX_cddc36d59d9c01921e0323b757" ON "vehicle_entries" ("companyName") `);
        await queryRunner.query(`CREATE INDEX "IDX_88091c5236edd6a4e72dba6441" ON "vehicle_entries" ("entryDate") `);
        await queryRunner.query(`CREATE INDEX "IDX_00d95e133c2734486068f0d654" ON "vehicle_entries" ("status") `);
        await queryRunner.query(`CREATE INDEX "IDX_34b242d96053f07e4696572f05" ON "vehicle_entries" ("assignedSalesmanId") `);
        await queryRunner.query(`CREATE TYPE "public"."sales_ordertype_enum" AS ENUM('ORDER', 'HAND_DELIVERY')`);
        await queryRunner.query(`CREATE TYPE "public"."sales_status_enum" AS ENUM('ENTERED', 'SALES_PENDING', 'SALES_COMPLETE', 'PAYMENT_PENDING', 'PAYMENT_COMPLETE', 'COMMISSION_PENDING', 'COMMISSION_COMPLETE', 'COMPLETED', 'NO_SALE')`);
        await queryRunner.query(`CREATE TABLE "sales" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "vehicleEntryId" uuid NOT NULL, "grossSale" numeric(12,2) NOT NULL, "netSale" numeric(12,2) NOT NULL, "salesperson" character varying NOT NULL, "orderType" "public"."sales_ordertype_enum" NOT NULL, "saleDate" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(), "status" "public"."sales_status_enum" NOT NULL DEFAULT 'SALES_COMPLETE', "notes" character varying, "createdById" uuid, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_4f0bc990ae81dba46da680895ea" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_71a937f64b90f28bea91a5e8f3" ON "sales" ("vehicleEntryId") `);
        await queryRunner.query(`CREATE INDEX "IDX_b2dc9f400bab51bc00239c8c9c" ON "sales" ("salesperson") `);
        await queryRunner.query(`CREATE INDEX "IDX_65f3c52de52446c1d23ed5daf2" ON "sales" ("saleDate") `);
        await queryRunner.query(`CREATE TYPE "public"."payments_mode_enum" AS ENUM('CC', 'IC', 'FC')`);
        await queryRunner.query(`CREATE TABLE "payments" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "saleId" uuid NOT NULL, "mode" "public"."payments_mode_enum" NOT NULL, "amount" numeric(12,2) NOT NULL, "paymentDate" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(), "notes" character varying, "createdById" uuid, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_197ab7af18c93fbb0c9b28b4a59" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_e15427928c7a02bd304d628c41" ON "payments" ("saleId") `);
        await queryRunner.query(`CREATE INDEX "IDX_27faf14e8959f0e40d7b722dc0" ON "payments" ("paymentDate") `);
        await queryRunner.query(`CREATE TYPE "public"."commissions_recipienttype_enum" AS ENUM('DRIVER', 'GUIDE', 'LOCAL_AGENT', 'COMPANY')`);
        await queryRunner.query(`CREATE TABLE "commissions" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "saleId" uuid NOT NULL, "recipientType" "public"."commissions_recipienttype_enum" NOT NULL, "recipientName" character varying NOT NULL, "rate" numeric(12,2) NOT NULL, "calculatedAmount" numeric(12,2) NOT NULL, "finalAmount" numeric(12,2) NOT NULL, "isOverridden" boolean NOT NULL DEFAULT false, "overrideReason" character varying, "overriddenById" uuid, "overriddenAt" TIMESTAMP, "paidAmount" numeric(12,2), "paidAt" date, "paidNote" text, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_2701379966e2e670bb5ff0ae78e" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_122588f5d349bcae6e6e461490" ON "commissions" ("saleId") `);
        await queryRunner.query(`CREATE INDEX "IDX_764069d5a03ccba682c794a906" ON "commissions" ("saleId", "recipientType") `);
        await queryRunner.query(`CREATE TYPE "public"."commission_configs_recipienttype_enum" AS ENUM('DRIVER', 'GUIDE', 'LOCAL_AGENT', 'COMPANY')`);
        await queryRunner.query(`CREATE TABLE "commission_configs" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "recipientType" "public"."commission_configs_recipienttype_enum" NOT NULL, "rate" numeric(5,2) NOT NULL, "updatedById" uuid, "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_4e5664937a28023f9fda6d3a2e0" UNIQUE ("recipientType"), CONSTRAINT "PK_6becd5fd41501c9c827eb710b1f" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."logistics_events_status_enum" AS ENUM('ENTERED', 'SALES_PENDING', 'SALES_COMPLETE', 'PAYMENT_PENDING', 'PAYMENT_COMPLETE', 'COMMISSION_PENDING', 'COMMISSION_COMPLETE', 'COMPLETED', 'NO_SALE')`);
        await queryRunner.query(`CREATE TABLE "logistics_events" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "vehicleEntryId" uuid NOT NULL, "status" "public"."logistics_events_status_enum" NOT NULL, "notes" character varying, "createdById" uuid, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_9ba84bfba4f9148a10e567c600c" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."audit_logs_action_enum" AS ENUM('VEHICLE_ENTRY_CREATED', 'VEHICLE_ENTRY_UPDATED', 'SALE_CREATED', 'SALE_UPDATED', 'PAYMENT_CREATED', 'PAYMENT_UPDATED', 'COMMISSION_CALCULATED', 'COMMISSION_OVERRIDDEN', 'STATUS_CHANGED', 'USER_CREATED', 'LOGIN', 'BILLING_ORDER_CREATED', 'BILLING_ORDER_UPDATED', 'BILLING_ORDER_DELETED', 'HAND_DELIVERY_CREATED', 'HAND_DELIVERY_UPDATED', 'HAND_DELIVERY_DELETED')`);
        await queryRunner.query(`CREATE TABLE "audit_logs" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "action" "public"."audit_logs_action_enum" NOT NULL, "entityType" character varying NOT NULL, "entityId" character varying, "userId" uuid, "oldValues" jsonb, "newValues" jsonb, "ipAddress" character varying, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_1bb179d048bbc581caa3b013439" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."notifications_type_enum" AS ENUM('VEHICLE_ENTRY', 'SALE', 'PAYMENT', 'COMMISSION')`);
        await queryRunner.query(`CREATE TABLE "notifications" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "type" "public"."notifications_type_enum" NOT NULL, "message" character varying NOT NULL, "entityId" character varying, "actorName" character varying, "isRead" boolean NOT NULL DEFAULT false, "actorId" uuid, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_6a72c3c0f683f6462415e653c3a" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "billing_items" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "billingOrderId" uuid NOT NULL, "particulars" character varying NOT NULL, "hsnCode" character varying(20), "size" character varying(50), "quantity" integer NOT NULL, "priceUsd" numeric(12,2) NOT NULL, "amountUsd" numeric(12,2) NOT NULL, CONSTRAINT "PK_9e3b8d77d9899c41dfd1335f364" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "billing_orders" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "invoiceNumber" character varying NOT NULL, "vehicleEntryId" uuid, "orderDate" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(), "status" character varying(20) NOT NULL DEFAULT 'DRAFT', "buyerName" character varying NOT NULL, "buyerAddress" character varying NOT NULL, "buyerCity" character varying NOT NULL, "buyerState" character varying NOT NULL, "buyerZip" character varying NOT NULL, "buyerCountry" character varying NOT NULL, "buyerEmail" character varying NOT NULL, "buyerWhatsApp" character varying NOT NULL, "buyerCellAreaCode" character varying, "buyerCellNo" character varying, "buyerPassportNo" character varying NOT NULL, "buyerDOB" date, "buyerNationality" character varying NOT NULL, "buyerSeaPort" character varying NOT NULL, "notes" character varying, "createdById" uuid, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_8494d55806bb3ba70b93e39ca4b" UNIQUE ("invoiceNumber"), CONSTRAINT "PK_9fef1dd3428ed46f79b24f4ac2b" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "hand_delivery_items" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "handDeliveryOrderId" uuid NOT NULL, "particulars" character varying NOT NULL, "hsnCode" character varying(20), "size" character varying(50), "quantity" integer NOT NULL, "priceInr" numeric(12,2) NOT NULL, "amountInr" numeric(12,2) NOT NULL, "gstRate" numeric(5,2) NOT NULL DEFAULT '5', "taxableValue" numeric(12,2) NOT NULL DEFAULT '0', "gstAmount" numeric(12,2) NOT NULL DEFAULT '0', CONSTRAINT "PK_cafe1e855ec558fe3111e638ee8" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "hand_delivery_orders" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "invoiceNumber" character varying NOT NULL, "orderDate" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(), "status" character varying(20) NOT NULL DEFAULT 'DRAFT', "invoiceType" character varying(20) NOT NULL DEFAULT 'INTER_STATE', "gstin" character varying, "dobPassport" character varying, "buyerName" character varying NOT NULL, "buyerState" character varying, "buyerCountry" character varying, "buyerEmail" character varying, "buyerCellAreaCode" character varying, "buyerCellNo" character varying, "buyerAddress" character varying, "buyerCity" character varying, "buyerZip" character varying, "buyerWhatsApp" character varying, "buyerPassportNo" character varying, "buyerDOB" date, "buyerNationality" character varying, "buyerSeaPort" character varying, "notes" character varying, "createdById" uuid, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_6aa2b2b710a1612f283780c830a" UNIQUE ("invoiceNumber"), CONSTRAINT "PK_689f518313e618a7dc8f4511272" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "billing_products" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "description" character varying NOT NULL, "hsnCode" character varying(20), "gstRate" numeric(5,2) NOT NULL DEFAULT '5', "isActive" boolean NOT NULL DEFAULT true, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_a750e7af6091f8883045f1c75e1" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE UNIQUE INDEX "IDX_185e3deb77a98a957c7bfe09d9" ON "billing_products" ("description") `);
        await queryRunner.query(`CREATE TABLE "shipments" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "billingOrderId" uuid, "carrier" character varying(20) NOT NULL, "serviceCode" character varying NOT NULL, "serviceLabel" character varying NOT NULL, "carrierShipmentId" character varying, "trackingNumber" character varying, "labelBase64" text, "status" character varying(20) NOT NULL DEFAULT 'LABEL_CREATED', "estimatedDelivery" date, "shipperName" character varying NOT NULL, "shipperAddress" character varying NOT NULL, "shipperCity" character varying NOT NULL, "shipperState" character varying NOT NULL, "shipperZip" character varying NOT NULL, "shipperCountry" character varying NOT NULL, "shipperPhone" character varying NOT NULL, "recipientName" character varying NOT NULL, "recipientAddress" character varying NOT NULL, "recipientCity" character varying NOT NULL, "recipientState" character varying NOT NULL, "recipientZip" character varying NOT NULL, "recipientCountry" character varying NOT NULL, "recipientPhone" character varying NOT NULL, "recipientEmail" character varying NOT NULL, "weightKg" numeric(8,3) NOT NULL, "lengthCm" numeric(8,1), "widthCm" numeric(8,1), "heightCm" numeric(8,1), "declaredValueUsd" numeric(12,2) NOT NULL, "contentsDescription" character varying NOT NULL, "quotedCostUsd" numeric(10,2), "shipDate" date NOT NULL, "createdById" uuid, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_6deda4532ac542a93eab214b564" PRIMARY KEY ("id"))`);
        await queryRunner.query(`ALTER TABLE "vehicle_entries" ADD CONSTRAINT "FK_0db0d0377116fe222eb81ec27c0" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "vehicle_entries" ADD CONSTRAINT "FK_34b242d96053f07e4696572f051" FOREIGN KEY ("assignedSalesmanId") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "sales" ADD CONSTRAINT "FK_71a937f64b90f28bea91a5e8f3b" FOREIGN KEY ("vehicleEntryId") REFERENCES "vehicle_entries"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "sales" ADD CONSTRAINT "FK_579a13a0f8d438c6f5a0d732556" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "payments" ADD CONSTRAINT "FK_e15427928c7a02bd304d628c41e" FOREIGN KEY ("saleId") REFERENCES "sales"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "payments" ADD CONSTRAINT "FK_8b8ddc119cf77e4a8968f47a703" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "commissions" ADD CONSTRAINT "FK_122588f5d349bcae6e6e461490a" FOREIGN KEY ("saleId") REFERENCES "sales"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "commissions" ADD CONSTRAINT "FK_2f9e10373c7517638297d9b5551" FOREIGN KEY ("overriddenById") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "commission_configs" ADD CONSTRAINT "FK_cb4f55d3fd4e1689f92e39b93fa" FOREIGN KEY ("updatedById") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "logistics_events" ADD CONSTRAINT "FK_39573aeb9112a1f285380c9ac64" FOREIGN KEY ("vehicleEntryId") REFERENCES "vehicle_entries"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "logistics_events" ADD CONSTRAINT "FK_85bd6bf5fc37802652c3a688f27" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "audit_logs" ADD CONSTRAINT "FK_cfa83f61e4d27a87fcae1e025ab" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "notifications" ADD CONSTRAINT "FK_44412a2d6f162ff4dc1697d0db7" FOREIGN KEY ("actorId") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "billing_items" ADD CONSTRAINT "FK_952e4b0328218b2d3ce983aaa6d" FOREIGN KEY ("billingOrderId") REFERENCES "billing_orders"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "billing_orders" ADD CONSTRAINT "FK_bfe015394ca6711327e26e1b255" FOREIGN KEY ("vehicleEntryId") REFERENCES "vehicle_entries"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "billing_orders" ADD CONSTRAINT "FK_8e8c5e1ceaaf1f5786bbde42d34" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "hand_delivery_items" ADD CONSTRAINT "FK_a0f4e6edf6fae5e51a8f604511f" FOREIGN KEY ("handDeliveryOrderId") REFERENCES "hand_delivery_orders"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "hand_delivery_orders" ADD CONSTRAINT "FK_7bd6093d24867c62f3345d33a82" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "shipments" ADD CONSTRAINT "FK_710ad3f8a6f94750e7d70db1e8a" FOREIGN KEY ("billingOrderId") REFERENCES "billing_orders"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "shipments" ADD CONSTRAINT "FK_96de1112a6c3b62bf5b5fc151df" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        // Reverting the baseline drops every table and all data. Refuse unless
        // explicitly allowed (e.g. on a throwaway local database).
        if (process.env.ALLOW_BASELINE_REVERT !== 'true') {
            throw new Error('Refusing to revert InitialSchema: it drops all tables. Set ALLOW_BASELINE_REVERT=true to override.');
        }

        await queryRunner.query(`ALTER TABLE "shipments" DROP CONSTRAINT "FK_96de1112a6c3b62bf5b5fc151df"`);
        await queryRunner.query(`ALTER TABLE "shipments" DROP CONSTRAINT "FK_710ad3f8a6f94750e7d70db1e8a"`);
        await queryRunner.query(`ALTER TABLE "hand_delivery_orders" DROP CONSTRAINT "FK_7bd6093d24867c62f3345d33a82"`);
        await queryRunner.query(`ALTER TABLE "hand_delivery_items" DROP CONSTRAINT "FK_a0f4e6edf6fae5e51a8f604511f"`);
        await queryRunner.query(`ALTER TABLE "billing_orders" DROP CONSTRAINT "FK_8e8c5e1ceaaf1f5786bbde42d34"`);
        await queryRunner.query(`ALTER TABLE "billing_orders" DROP CONSTRAINT "FK_bfe015394ca6711327e26e1b255"`);
        await queryRunner.query(`ALTER TABLE "billing_items" DROP CONSTRAINT "FK_952e4b0328218b2d3ce983aaa6d"`);
        await queryRunner.query(`ALTER TABLE "notifications" DROP CONSTRAINT "FK_44412a2d6f162ff4dc1697d0db7"`);
        await queryRunner.query(`ALTER TABLE "audit_logs" DROP CONSTRAINT "FK_cfa83f61e4d27a87fcae1e025ab"`);
        await queryRunner.query(`ALTER TABLE "logistics_events" DROP CONSTRAINT "FK_85bd6bf5fc37802652c3a688f27"`);
        await queryRunner.query(`ALTER TABLE "logistics_events" DROP CONSTRAINT "FK_39573aeb9112a1f285380c9ac64"`);
        await queryRunner.query(`ALTER TABLE "commission_configs" DROP CONSTRAINT "FK_cb4f55d3fd4e1689f92e39b93fa"`);
        await queryRunner.query(`ALTER TABLE "commissions" DROP CONSTRAINT "FK_2f9e10373c7517638297d9b5551"`);
        await queryRunner.query(`ALTER TABLE "commissions" DROP CONSTRAINT "FK_122588f5d349bcae6e6e461490a"`);
        await queryRunner.query(`ALTER TABLE "payments" DROP CONSTRAINT "FK_8b8ddc119cf77e4a8968f47a703"`);
        await queryRunner.query(`ALTER TABLE "payments" DROP CONSTRAINT "FK_e15427928c7a02bd304d628c41e"`);
        await queryRunner.query(`ALTER TABLE "sales" DROP CONSTRAINT "FK_579a13a0f8d438c6f5a0d732556"`);
        await queryRunner.query(`ALTER TABLE "sales" DROP CONSTRAINT "FK_71a937f64b90f28bea91a5e8f3b"`);
        await queryRunner.query(`ALTER TABLE "vehicle_entries" DROP CONSTRAINT "FK_34b242d96053f07e4696572f051"`);
        await queryRunner.query(`ALTER TABLE "vehicle_entries" DROP CONSTRAINT "FK_0db0d0377116fe222eb81ec27c0"`);
        await queryRunner.query(`DROP TABLE "shipments"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_185e3deb77a98a957c7bfe09d9"`);
        await queryRunner.query(`DROP TABLE "billing_products"`);
        await queryRunner.query(`DROP TABLE "hand_delivery_orders"`);
        await queryRunner.query(`DROP TABLE "hand_delivery_items"`);
        await queryRunner.query(`DROP TABLE "billing_orders"`);
        await queryRunner.query(`DROP TABLE "billing_items"`);
        await queryRunner.query(`DROP TABLE "notifications"`);
        await queryRunner.query(`DROP TYPE "public"."notifications_type_enum"`);
        await queryRunner.query(`DROP TABLE "audit_logs"`);
        await queryRunner.query(`DROP TYPE "public"."audit_logs_action_enum"`);
        await queryRunner.query(`DROP TABLE "logistics_events"`);
        await queryRunner.query(`DROP TYPE "public"."logistics_events_status_enum"`);
        await queryRunner.query(`DROP TABLE "commission_configs"`);
        await queryRunner.query(`DROP TYPE "public"."commission_configs_recipienttype_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_764069d5a03ccba682c794a906"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_122588f5d349bcae6e6e461490"`);
        await queryRunner.query(`DROP TABLE "commissions"`);
        await queryRunner.query(`DROP TYPE "public"."commissions_recipienttype_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_27faf14e8959f0e40d7b722dc0"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_e15427928c7a02bd304d628c41"`);
        await queryRunner.query(`DROP TABLE "payments"`);
        await queryRunner.query(`DROP TYPE "public"."payments_mode_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_65f3c52de52446c1d23ed5daf2"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_b2dc9f400bab51bc00239c8c9c"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_71a937f64b90f28bea91a5e8f3"`);
        await queryRunner.query(`DROP TABLE "sales"`);
        await queryRunner.query(`DROP TYPE "public"."sales_status_enum"`);
        await queryRunner.query(`DROP TYPE "public"."sales_ordertype_enum"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_34b242d96053f07e4696572f05"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_00d95e133c2734486068f0d654"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_88091c5236edd6a4e72dba6441"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_cddc36d59d9c01921e0323b757"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_c4c0bcb0eee3185854a933686a"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_5b84c2372a5038a0b155c3bccd"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_ab4cbac9d722c3f229d3de2c51"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_e2c39fbcc81942d651b9ab023f"`);
        await queryRunner.query(`DROP TABLE "vehicle_entries"`);
        await queryRunner.query(`DROP TYPE "public"."vehicle_entries_status_enum"`);
        await queryRunner.query(`DROP TABLE "users"`);
        await queryRunner.query(`DROP TYPE "public"."users_role_enum"`);
    }

}
