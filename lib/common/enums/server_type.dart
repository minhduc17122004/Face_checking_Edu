enum ServerType { none, odoo, sap, aws }

extension ServerTypeExtension on ServerType {
  String get value {
    switch (this) {
      case ServerType.none:
        return 'none';
      case ServerType.odoo:
        return 'odoo';
      case ServerType.sap:
        return 'SAP';
      case ServerType.aws:
        return 'AWS';
    }
  }

  String get label {
    switch (this) {
      case ServerType.none:
        return 'None';
      case ServerType.odoo:
        return 'Odoo';
      case ServerType.sap:
        return 'SAP';
      case ServerType.aws:
        return 'AWS';
    }
  }

  static ServerType? fromString(String? s) {
    if (s == null) return null;
    final lower = s.toLowerCase();
    if (lower == 'none') return ServerType.none;
    if (lower == 'odoo') return ServerType.odoo;
    if (lower == 'sap') return ServerType.sap;
    if (lower == 'aws') return ServerType.aws;
    return ServerType.none;
  }
}

ServerType? serverTypeFromString(String? s) => ServerTypeExtension.fromString(s);
