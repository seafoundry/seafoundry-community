const { db, config } = require('../config-json');

class BaseSeeder {
    constructor(collectionName) {
        this.collectionName = collectionName;
        this.collection = db.collection(collectionName);
    }

    async seed(data, options = {}) {
        const { batchSize = 500, overwrite = false, verbose = false } = options;

        console.log(`🌱 Seeding ${this.collectionName}...`);

        if (!Array.isArray(data)) {
            throw new Error(`Data must be an array for ${this.collectionName}`);
        }

        if (data.length === 0) {
            console.log(`⚠️  No data to seed for ${this.collectionName}`);
            return;
        }

        // Check if collection already has data
        if (!overwrite) {
            try {
                const existingDocs = await this.collection.limit(1).get();
                if (!existingDocs.empty) {
                    console.log(`⚠️  Collection ${this.collectionName} already has data. Skipping...`);
                    return;
                }
            } catch (error) {
                // Collection doesn't exist yet, which is fine - we'll create it
                if (verbose) {
                    console.log(`  📁 Collection ${this.collectionName} doesn't exist yet. Will create it.`);
                }
            }
        }

        if (verbose) {
            console.log(`  📝 Data to seed: ${data.length} records`);
            console.log(`  📊 Collection path: ${this.collection.path}`);
            console.log(`  🔄 Overwrite mode: ${overwrite}`);
        }

        // Process in batches
        const batches = [];
        for (let i = 0; i < data.length; i += batchSize) {
            batches.push(data.slice(i, i + batchSize));
        }

        let totalSeeded = 0;

        for (let i = 0; i < batches.length; i++) {
            const batch = batches[i];
            const writeBatch = db.batch();

            batch.forEach(item => {
                if (!item.id) {
                    throw new Error(`Item missing id in ${this.collectionName}: ${JSON.stringify(item)}`);
                }

                const docRef = this.collection.doc(item.id);
                writeBatch.set(docRef, item);

                if (verbose && i === 0) {
                    console.log(`    📄 Writing document: ${item.id}`);
                }
            });

            try {
                await writeBatch.commit();
                totalSeeded += batch.length;
                console.log(`  ✅ Batch ${i + 1}/${batches.length}: ${batch.length} records`);
            } catch (error) {
                console.error(`❌ Error writing batch ${i + 1}:`, error.message);
                throw error;
            }
        }

        console.log(`✅ Successfully seeded ${totalSeeded} ${this.collectionName} records`);
    }

  async clear() {
    console.log(`🗑️  Clearing ${this.collectionName}...`);

    const snapshot = await this.collection.get();
    const batch = db.batch();

    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`✅ Cleared ${snapshot.docs.length} ${this.collectionName} records`);
  }

  async deleteByIds(ids, options = {}) {
    if (!Array.isArray(ids) || ids.length === 0) {
      return;
    }

    const { batchSize = 500, verbose = false } = options;

    const chunks = [];
    for (let i = 0; i < ids.length; i += batchSize) {
      chunks.push(ids.slice(i, i + batchSize));
    }

    let total = 0;

    for (let i = 0; i < chunks.length; i++) {
      const chunk = chunks[i];
      const batch = db.batch();
      chunk.forEach(id => {
        const ref = this.collection.doc(id);
        batch.delete(ref);
        if (verbose && i === 0) {
          console.log(`    🗑️  Queued delete: ${this.collectionName}/${id}`);
        }
      });

      await batch.commit();
      total += chunk.length;
      console.log(
        `  ✅ Batch ${i + 1}/${chunks.length}: deleted ${chunk.length} ` +
        `${this.collectionName} records`
      );
    }

    console.log(
      `✅ Cleared ${total} ${this.collectionName} record(s) by id`,
    );
  }

  async count() {
    const snapshot = await this.collection.get();
    return snapshot.docs.length;
  }
}

module.exports = BaseSeeder; 
