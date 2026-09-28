/// Sri Lanka's fishery harbours and major fish landing sites, grouped by
/// district (per Dept. of Fisheries & Aquatic Resources / NAQDA harbour
/// network) -- used as the fixed choice list for "home harbour" instead of
/// free text, so trip logs and zone distance estimates use a consistent
/// name/location.
class SriLankaHarbours {
  SriLankaHarbours._();

  static const Map<String, List<String>> byDistrict = {
    'Colombo': [
      'Colombo Fishery Harbour',
      'Mutwal Fish Landing Site',
    ],
    'Gampaha': [
      'Negombo Fishery Harbour',
      'Wella Odaya Fish Landing Site',
      'Dikkowita Fishery Harbour',
    ],
    'Puttalam': [
      'Chilaw Fishery Harbour',
      'Puttalam Fishery Harbour',
      'Kalpitiya Fishery Harbour',
      'Mundel Fish Landing Site',
    ],
    'Mannar': [
      'Mannar Fishery Harbour',
      'Pesalai Fish Landing Site',
      'Talaimannar Fish Landing Site',
    ],
    'Jaffna': [
      'Myliddy Fishery Harbour',
      'Karainagar Fishery Harbour',
      'Gurunagar Fishery Harbour',
      'Point Pedro Fishery Harbour',
      'Kudathanai Fish Landing Site',
      'Valvettithurai Fishery Harbour',
    ],
    'Kilinochchi': [
      'Nachchikuda Fishery Harbour',
      'Chalai Fish Landing Site',
    ],
    'Mullaitivu': [
      'Mullaitivu Fish Landing Site',
      'Chempiyanpattu Fish Landing Site',
    ],
    'Trincomalee': [
      'Trincomalee Fishery Harbour',
      'Nilaveli Fish Landing Site',
      'Mutur Fish Landing Site',
    ],
    'Batticaloa': [
      'Kattankudy Fishery Harbour',
      'Batticaloa Fish Landing Site',
      'Valachchenai Fish Landing Site',
    ],
    'Ampara': [
      'Oluvil Fishery Harbour',
      'Kalmunai Fish Landing Site',
      'Pottuvil Fish Landing Site',
    ],
    'Hambantota': [
      'Hambantota Fishery Harbour',
      'Kirinda Fishery Harbour',
      'Tangalle Fishery Harbour',
    ],
    'Matara': [
      'Mirissa Fishery Harbour',
      'Dondra Fish Landing Site',
    ],
    'Galle': [
      'Galle Fishery Harbour',
      'Gintota Fish Landing Site',
      'Dodanduwa Fish Landing Site',
    ],
    'Kalutara': [
      'Beruwala Fishery Harbour',
      'Panadura Fish Landing Site',
    ],
  };

  static List<String> get all =>
      byDistrict.values.expand((v) => v).toList(growable: false);
}
