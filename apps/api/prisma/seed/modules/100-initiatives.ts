import { defineSeedModule } from '../types';

/** Placeholder registered by V2 TASK-01; TASK-12 fills `run` (sample civic drives and RSVPs). */
export default defineSeedModule({
  name: 'initiatives',
  requires: ['initiatives'],
  async run({ log }) {
    log('Seed initiatives: module not implemented yet (TASK-12)');
  },
});
