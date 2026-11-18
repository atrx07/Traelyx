import { createHash } from 'node:crypto';

/** Read-only, in-process fingerprints; never expose file names, private bytes or credentials. */
export async function mainPreservationFingerprint(adb) {
  const mainPackage = 'io.github.atrx07.traelyx';
  const hashes = [];
  for (const directory of ['no_backup/recorder', 'no_backup/guardian', 'shared_prefs']) {
    let listing;
    try { listing = await adb(['shell', 'run-as', mainPackage, 'ls', directory]); }
    catch (error) {
      if (String(error.stderr).includes('No such file or directory')) { hashes.push('absent'); continue; }
      throw new Error('main_preservation_unreadable');
    }
    if (directory === 'no_backup/recorder' && /active_trip_v1\.bin/.test(listing)) throw new Error('main_recorder_not_idle');
    const data = await adb(['shell', 'run-as', mainPackage, 'find', directory, '-type', 'f',
      '-exec', 'sha256sum', '{}', '+'], 60_000);
    hashes.push(createHash('sha256').update(data.split(/\r?\n/).filter(Boolean).sort().join('\n')).digest('hex'));
  }
  return hashes;
}
