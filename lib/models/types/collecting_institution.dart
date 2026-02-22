// @tier: community
class CollectingInstitution {
  const CollectingInstitution({required this.id, required this.name});

  final String id; // Stored value
  final String name; // Display label

  static const CollectingInstitution um = CollectingInstitution(id: 'University of Miami', name: 'University of Miami');
  static const CollectingInstitution nsu = CollectingInstitution(
    id: 'Nova Southeastern University',
    name: 'Nova Southeastern University',
  );
  static const CollectingInstitution fiu = CollectingInstitution(
    id: 'Florida International University',
    name: 'Florida International University',
  );
  static const CollectingInstitution mote = CollectingInstitution(
    id: 'Mote Marine Laboratory',
    name: 'Mote Marine Laboratory',
  );
  static const CollectingInstitution crf = CollectingInstitution(
    id: 'Coral Restoration Foundation',
    name: 'Coral Restoration Foundation',
  );
  static const CollectingInstitution rrf = CollectingInstitution(
    id: 'Reef Renewal Foundation',
    name: 'Reef Renewal Foundation',
  );
  static const CollectingInstitution tnc = CollectingInstitution(
    id: 'The Nature Conservancy',
    name: 'The Nature Conservancy',
  );
  static const CollectingInstitution noaa = CollectingInstitution(id: 'NOAA', name: 'NOAA');
  static const CollectingInstitution usgs = CollectingInstitution(id: 'USGS', name: 'USGS');
  static const CollectingInstitution other = CollectingInstitution(id: 'Other', name: 'Other');

  static const List<CollectingInstitution> builtins = [um, nsu, fiu, mote, crf, rrf, tnc, noaa, usgs, other];
}
