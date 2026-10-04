import { defineSeedModule } from '../types';

/** Placeholder registered by V2 TASK-01; TASK-09 fills `run` (fictional "Sample" corporators per ward). */
export default defineSeedModule({
  name: 'representatives',
  requires: ['representatives'],
  async run({ log }) {
    log('Seed representatives: module not implemented yet (TASK-09)');
  },
});
