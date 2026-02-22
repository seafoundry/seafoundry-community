// @tier: community
import 'package:seafoundry_app/models/public_read_models/public_impact_point.dart';

/// Filter options for CRC historical data
class CrcFilterOptions {
  static const List<String> regions = ['Upper Keys', 'Middle Keys', 'Lower Keys'];
  static const List<String> reefs = [
    'Carysfort Reef',
    'Elbow Reef', 
    'French Reef',
    'Sombrero Reef',
    'Delta Shoals',
    'Coffins Patch',
    'Looe Key',
    'Eastern Dry Rocks',
    'Sand Key',
    'Molasses Reef',
    'Conch Reef',
  ];
  static const List<String> species = [
    'Acropora cervicornis',
    'Acropora palmata',
    'Orbicella faveolata',
    'Orbicella annularis',
    'Montastraea cavernosa',
    'Diploria labyrinthiformis',
  ];
  static const List<String> genets = [
    'AC-001', 'AC-002', 'AC-003', 'AC-004', 'AC-005',
    'AC-012', 'AC-015', 'AC-018', 'AC-021', 'AC-024',
    'AP-001', 'AP-002', 'AP-003', 'AP-004',
    'OF-001', 'OF-002', 'OF-003',
    'OA-001', 'OA-002',
    'MC-001', 'MC-002',
    'DL-001',
  ];
}

/// Extended sample point with filter metadata
class CrcImpactPoint {
  const CrcImpactPoint({
    required this.point,
    required this.region,
    required this.reef,
    required this.species,
    this.year,
    this.genets = const [],
  });
  
  final PublicImpactPoint point;
  final String region;
  final String reef;
  final String species;
  final int? year;
  final List<String> genets; // Genet/genotype IDs at this site
}

/// Shared sample points used when previewing impact maps without geo metadata.
/// Includes CRC historical data representative points from Florida Keys restoration efforts.
final List<CrcImpactPoint> crcSampleData = [
  // CRC Historical Data - Upper Keys Region
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'crc-upper-1',
      organizationId: 'crc',
      latitude: 25.0126,
      longitude: -80.3974,
      pointType: PublicImpactPointType.outplant,
      magnitude: 2847,
      label: 'Carysfort Reef',
    ),
    region: 'Upper Keys',
    reef: 'Carysfort Reef',
    species: 'Acropora cervicornis',
    year: 2022,
    genets: ['AC-001', 'AC-002', 'AC-003', 'AC-012', 'AC-015'],
  ),
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'crc-upper-2',
      organizationId: 'crc',
      latitude: 25.0553,
      longitude: -80.3761,
      pointType: PublicImpactPointType.outplant,
      magnitude: 1523,
      label: 'Elbow Reef',
    ),
    region: 'Upper Keys',
    reef: 'Elbow Reef',
    species: 'Acropora palmata',
    year: 2021,
    genets: ['AP-001', 'AP-002', 'AP-003'],
  ),
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'crc-upper-3',
      organizationId: 'crc',
      latitude: 24.9825,
      longitude: -80.4183,
      pointType: PublicImpactPointType.outplant,
      magnitude: 1891,
      label: 'French Reef',
    ),
    region: 'Upper Keys',
    reef: 'French Reef',
    species: 'Orbicella faveolata',
    year: 2023,
    genets: ['OF-001', 'OF-002', 'OF-003'],
  ),
  // CRC Historical Data - Middle Keys Region
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'crc-middle-1',
      organizationId: 'crc',
      latitude: 24.7234,
      longitude: -80.8621,
      pointType: PublicImpactPointType.outplant,
      magnitude: 3156,
      label: 'Sombrero Reef',
    ),
    region: 'Middle Keys',
    reef: 'Sombrero Reef',
    species: 'Acropora cervicornis',
    year: 2022,
    genets: ['AC-001', 'AC-004', 'AC-005', 'AC-018', 'AC-021'],
  ),
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'crc-middle-2',
      organizationId: 'crc',
      latitude: 24.6891,
      longitude: -80.9423,
      pointType: PublicImpactPointType.outplant,
      magnitude: 2234,
      label: 'Delta Shoals',
    ),
    region: 'Middle Keys',
    reef: 'Delta Shoals',
    species: 'Orbicella annularis',
    year: 2021,
    genets: ['OA-001', 'OA-002'],
  ),
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'crc-middle-3',
      organizationId: 'crc',
      latitude: 24.7512,
      longitude: -80.7834,
      pointType: PublicImpactPointType.outplant,
      magnitude: 1678,
      label: 'Coffins Patch',
    ),
    region: 'Middle Keys',
    reef: 'Coffins Patch',
    species: 'Montastraea cavernosa',
    year: 2023,
    genets: ['MC-001', 'MC-002'],
  ),
  // CRC Historical Data - Lower Keys Region
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'crc-lower-1',
      organizationId: 'crc',
      latitude: 24.5489,
      longitude: -81.4023,
      pointType: PublicImpactPointType.outplant,
      magnitude: 2567,
      label: 'Looe Key',
    ),
    region: 'Lower Keys',
    reef: 'Looe Key',
    species: 'Acropora cervicornis',
    year: 2022,
    genets: ['AC-002', 'AC-003', 'AC-012', 'AC-024'],
  ),
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'crc-lower-2',
      organizationId: 'crc',
      latitude: 24.4623,
      longitude: -81.8234,
      pointType: PublicImpactPointType.outplant,
      magnitude: 1945,
      label: 'Eastern Dry Rocks',
    ),
    region: 'Lower Keys',
    reef: 'Eastern Dry Rocks',
    species: 'Acropora palmata',
    year: 2021,
    genets: ['AP-001', 'AP-004'],
  ),
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'crc-lower-3',
      organizationId: 'crc',
      latitude: 24.4512,
      longitude: -81.9123,
      pointType: PublicImpactPointType.outplant,
      magnitude: 2123,
      label: 'Sand Key',
    ),
    region: 'Lower Keys',
    reef: 'Sand Key',
    species: 'Diploria labyrinthiformis',
    year: 2023,
    genets: ['DL-001'],
  ),
  // Nursery Holdings - In-water nurseries
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'nursery-1',
      organizationId: 'crc',
      latitude: 24.8234,
      longitude: -80.7512,
      pointType: PublicImpactPointType.holding,
      magnitude: 4521,
      label: 'Tavernier Nursery',
    ),
    region: 'Upper Keys',
    reef: 'Tavernier Nursery',
    species: 'Acropora cervicornis',
    year: 2023,
    genets: ['AC-001', 'AC-002', 'AC-003', 'AC-004', 'AC-005', 'AC-012', 'AC-015', 'AC-018', 'AC-021', 'AC-024'],
  ),
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'nursery-2',
      organizationId: 'crc',
      latitude: 24.5612,
      longitude: -81.7234,
      pointType: PublicImpactPointType.holding,
      magnitude: 3845,
      label: 'Key West Nursery',
    ),
    region: 'Lower Keys',
    reef: 'Key West Nursery',
    species: 'Acropora palmata',
    year: 2023,
    genets: ['AP-001', 'AP-002', 'AP-003', 'AP-004'],
  ),
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'nursery-3',
      organizationId: 'crc',
      latitude: 24.6923,
      longitude: -81.1234,
      pointType: PublicImpactPointType.holding,
      magnitude: 2987,
      label: 'Marathon Nursery',
    ),
    region: 'Middle Keys',
    reef: 'Marathon Nursery',
    species: 'Orbicella faveolata',
    year: 2023,
    genets: ['OF-001', 'OF-002', 'OF-003', 'OA-001', 'OA-002', 'MC-001', 'MC-002'],
  ),
  // Community Partner Sites
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'partner-1',
      organizationId: 'community',
      latitude: 24.9123,
      longitude: -80.5234,
      pointType: PublicImpactPointType.outplant,
      magnitude: 856,
      label: 'Molasses Reef',
    ),
    region: 'Upper Keys',
    reef: 'Molasses Reef',
    species: 'Acropora cervicornis',
    year: 2023,
    genets: ['AC-001', 'AC-015'],
  ),
  CrcImpactPoint(
    point: const PublicImpactPoint.sample(
      id: 'partner-2',
      organizationId: 'community',
      latitude: 24.8534,
      longitude: -80.6123,
      pointType: PublicImpactPointType.outplant,
      magnitude: 623,
      label: 'Conch Reef',
    ),
    region: 'Upper Keys',
    reef: 'Conch Reef',
    species: 'Orbicella faveolata',
    year: 2022,
    genets: ['OF-002'],
  ),
];

/// Legacy accessor for backward compatibility
List<PublicImpactPoint> get sampleImpactPoints => 
    crcSampleData.map((e) => e.point).toList();
