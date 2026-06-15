import 'package:flutter/material.dart';

import 'distribution_service.dart';

class DistributionSearchScreen extends StatefulWidget {
  const DistributionSearchScreen({super.key});

  @override
  State<DistributionSearchScreen> createState() =>
      _DistributionSearchScreenState();
}

class _DistributionSearchScreenState extends State<DistributionSearchScreen> {
  final searchController = TextEditingController();
  final service = DistributionService();

  bool loading = false;
  bool verifying = false;
  List<Map<String, dynamic>> results = [];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> search() async {
    setState(() {
      loading = true;
    });

    try {
      final data = await service.searchBeneficiaries(searchController.text);

      if (!mounted) return;

      setState(() {
        results = data;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<bool> confirmFaceMatch(String faceUrl) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Face Match'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Image.network(
                  faceUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Does the live beneficiary match this registered photo?',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check),
              label: const Text('Yes, matches'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> verifyAndDistribute(Map<String, dynamic> beneficiary) async {
    if (verifying) return;

    setState(() {
      verifying = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Loading registered face photo...')),
      );

      final beneficiaryId = beneficiary['id'] as String;
      final programId = beneficiary['program_id'] as String;

      final faceUrl = await service.getRegisteredFaceUrl(beneficiaryId);

      if (!mounted) return;

      if (faceUrl == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('No registered face photo found. Distribution blocked.'),
          ),
        );
        return;
      }

      final faceConfirmed = await confirmFaceMatch(faceUrl);

      if (!mounted) return;

      if (!faceConfirmed) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Face verification rejected.')),
        );
        return;
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Checking simulated fingerprint...')),
      );

      final fingerprintMatched = await service.verifyFingerprint(beneficiaryId);

      if (!mounted) return;

      if (!fingerprintMatched) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Fingerprint verification failed. Distribution blocked.'),
          ),
        );
        return;
      }

      await service.recordDistribution(
        beneficiaryId: beneficiaryId,
        programId: programId,
      );

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Face and fingerprint matched. Distribution recorded.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          verifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distribution'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search by name, phone, or ID',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: search,
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (loading) const CircularProgressIndicator(),

            if (verifying)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Verification in progress...'),
              ),

            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final beneficiary = results[index];

                  return Card(
                    child: ListTile(
                      title: Text(
                        beneficiary['full_name'] ?? 'Unnamed Beneficiary',
                      ),
                      subtitle: Text(
                        'Phone: ${beneficiary['phone'] ?? 'N/A'}',
                      ),
                      trailing: ElevatedButton(
                        onPressed: verifying
                            ? null
                            : () => verifyAndDistribute(beneficiary),
                        child: const Text('Verify'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}