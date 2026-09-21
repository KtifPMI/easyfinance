class MasterStatus {
  final bool isActive;
  final bool isMasterCompleted;
  final List<int> masterChain;

  MasterStatus({
    required this.isActive,
    required this.isMasterCompleted,
    required this.masterChain,
  });

  factory MasterStatus.fromJson(Map<String, dynamic> json) {
    final master = json['master'] as Map<String, dynamic>?;
    if (master == null) {
      return MasterStatus(isActive: false, isMasterCompleted: true, masterChain: []);
    }
    final chainRaw = master['master_chain'];
    List<int> chain = [];
    if (chainRaw is List) {
      chain = chainRaw.map((e) => (e is int) ? e : int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toList();
    }
    return MasterStatus(
      isActive: master['is_active'] == true,
      isMasterCompleted: master['is_master_completed'] == true,
      masterChain: chain,
    );
  }
}
