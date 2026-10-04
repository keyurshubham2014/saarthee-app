import { defineSeedModule } from '../types';

/** Placeholder registered by V2 TASK-01; TASK-02 fills `run` (48 wards and 7 zones from the committed OpenCity GeoJSON + AMC ward list, then backfill seeded issues). */
export default defineSeedModule({
  name: 'wards',
  requires: ['zones', 'wards'],
  async run({ log }) {
    log('Seed wards: module not implemented yet (TASK-02)');
  },
});
