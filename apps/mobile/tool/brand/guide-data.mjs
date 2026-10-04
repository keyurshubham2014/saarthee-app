// Brand-guide data copied from docs/v2/design-system.md DS §1–§4.
export const palette = [
  ['primary', '#14674A', 'Brand header, filled buttons, links, selected nav'],
  ['primaryDark', '#0E4A35', 'Pressed state, toast background'],
  ['primaryContainer', '#E1F0E7', 'Selected nav indicator, tonal buttons'],
  ['sunrise', '#C24A1F', 'Report action only (once per screen) and the mark dot'],
  ['background', '#F3F6F1', 'Page background (leaf-tinted)'],
  ['surface', '#FFFFFF', 'Cards, sheets, bottom bar'],
  ['border', '#DCE5DE', 'Card borders, dividers'],
  ['textPrimary', '#17251E', 'Body text (15.9:1 on white)'],
  ['textSecondary', '#4E5E55', 'Metadata (6.9:1 on white)'],
];
export const dark = [
  ['background', '#131C18'], ['surface', '#1A2520'], ['border', '#2A3830'],
  ['textPrimary', '#E6EFE9'], ['textSecondary', '#A9B9AF'], ['primary', '#7BD3A6'], ['sunrise', '#FF9E78'],
];
export const statuses = [
  ['Reported', 'નોંધાયેલ', '#4B5768', '#EDF0F4', 'radio_button_unchecked'],
  ['Acknowledged', 'સ્વીકારાયેલ', '#1F5FAE', '#E5EEFA', 'mark_email_read'],
  ['In progress', 'કામ ચાલુ', '#8A5300', '#FFF3DC', 'construction'],
  ['Fixed', 'ઉકેલાયેલ', '#1A7340', '#E6F4EC', 'check_circle'],
  ['Verified', 'ચકાસાયેલ', '#0E5233', '#DDEFE5', 'verified'],
  ['Reopened', 'ફરી ખોલાયેલ', '#B4400F', '#FDEDE4', 'replay'],
  ['Not accepted', 'સ્વીકાર્ય નથી', '#8A2234', '#F8E7EA', 'block'],
];
export const categories = [
  ['roads', '#5A5F66', 'road'], ['water', '#1D5E9E', 'water_drop'],
  ['drainage', '#3F5E73', 'water_damage'], ['garbage', '#5C6B2E', 'delete'],
  ['streetlight', '#8A5F00', 'lightbulb'], ['trees', '#2E6B45', 'park'],
  ['animals', '#7A4E2D', 'pets'], ['health', '#7A3F6B', 'pest_control'],
  ['toilets', '#2F6670', 'wc'], ['encroachment', '#8C3B2E', 'do_not_step'],
  ['traffic', '#9C3D1A', 'traffic'], ['property', '#4F5A7A', 'receipt_long'],
  ['building', '#6B4F3A', 'apartment'], ['other', '#66707C', 'more_horiz'],
];
export const type = [
  ['displaySmall', 'Baloo', 28, 700, 36, 'Namaste, Keyur · નમસ્તે'],
  ['headlineSmall', 'Baloo', 24, 700, 32, 'What is the problem? · સમસ્યા શું છે?'],
  ['titleLarge', 'Baloo', 19, 600, 26, 'Near you · તમારી નજીક'],
  ['titleMedium', 'Mukta', 16, 600, 22, 'Streetlight not working · સ્ટ્રીટલાઇટ બંધ છે'],
  ['bodyLarge', 'Mukta', 16, 400, 24, 'Reported 2 days ago in Navrangpura ward.'],
  ['labelLarge', 'Mukta', 15.5, 600, 20, 'Submit report · ફરિયાદ મોકલો'],
  ['bodySmall', 'Mukta', 12, 400, 17, 'Faces and number plates blurred'],
];
export const dos = [
  'Use the full-colour mark on white, #F3F6F1 or dark #131C18; on primary use mark-reversed.',
  'Keep 25% of the mark size clear on every side.',
  'Put English and Gujarati side by side, or swap them by locale.',
  'Show the independence line wherever AMC is mentioned.',
];
export const donts = [
  'Recolour the mark or the dot (no AMC bronze, amber, navy or teal).',
  'Stack English over Gujarati.',
  'Add a seal, circle emblem, wheel, chakra or building.',
  'Rotate, outline, add shadows to or stretch the mark.',
  'Use "AMC" in the app name, icon or store title.',
];
