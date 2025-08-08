import * as path from 'path';
import * as Mocha from 'mocha';
import { glob } from 'glob';

export function run(): Promise<void> {
  // Create the mocha test for E2E coordination tests
  const mocha = new Mocha({
    ui: 'tdd',
    color: true,
    timeout: 60000, // Longer timeout for E2E tests
    slow: 5000
  });

  const testsRoot = path.resolve(__dirname, '..');

  return new Promise((resolve, reject) => {
    glob('**/e2e-coordination*.test.js', { cwd: testsRoot })
      .then(files => {
        // Add files to the test suite
        files.forEach(f => mocha.addFile(path.resolve(testsRoot, f)));

        try {
          // Run the mocha test
          mocha.run(failures => {
            if (failures > 0) {
              reject(new Error(`${failures} E2E coordination tests failed.`));
            } else {
              resolve();
            }
          });
        } catch (err) {
          console.error(err);
          reject(err);
        }
      })
      .catch(err => {
        return reject(err);
      });
  });
}
