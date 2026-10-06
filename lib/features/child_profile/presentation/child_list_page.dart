import 'package:flutter/material.dart';
import '../data/child_repository.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import 'child_registration_page.dart';

class ChildListPage extends StatefulWidget {
  const ChildListPage({super.key});

  @override
  State<ChildListPage> createState() => _ChildListPageState();
}

class _ChildListPageState extends State<ChildListPage> {
  final ChildRepository _repository = ChildRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  List<ChildModel> _allChildren = [];
  List<ChildModel> _filteredChildren = [];
  String _searchQuery = '';
  String _selectedGenderFilter = 'All';
  String _sortBy = 'Name A-Z';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshChildren();
  }

  Future<void> _refreshChildren() async {
    setState(() => _isLoading = true);
    final data = await _repository.getChildren();
    setState(() {
      _allChildren = data;
      _applyFilterAndSort();
      _isLoading = false;
    });
  }

  void _applyFilterAndSort() {
    setState(() {
      final q = _searchQuery.toLowerCase();
      _filteredChildren = _allChildren.where((child) {
        final name = "${child.firstName} ${child.lastName}".toLowerCase();
        final matchesSearch = name.contains(q) ||
            child.childId.toLowerCase().contains(q) ||
            child.parentName.toLowerCase().contains(q);

        final matchesGender = _selectedGenderFilter == 'All' ||
            child.gender.toLowerCase() == _selectedGenderFilter.toLowerCase();

        return matchesSearch && matchesGender;
      }).toList();

      _filteredChildren.sort((a, b) {
        switch (_sortBy) {
          case 'Name Z-A':
            return "${b.firstName} ${b.lastName}".toLowerCase().compareTo("${a.firstName} ${a.lastName}".toLowerCase());
          case 'Age (Youngest)':
            return a.age.compareTo(b.age);
          case 'Age (Oldest)':
            return b.age.compareTo(a.age);
          case 'Name A-Z':
          default:
            return "${a.firstName} ${a.lastName}".toLowerCase().compareTo("${b.firstName} ${b.lastName}".toLowerCase());
        }
      });
    });
  }

  void _deleteChild(ChildModel child) async {
    final confirmed = await ConfirmationDialog.showDelete(
      context: context,
      itemName: '${child.firstName} ${child.lastName}',
    );

    if (confirmed) {
      await _repository.deleteChild(child.id!);
      _refreshChildren();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Child profile deleted successfully')));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Profiles'),
        actions: [
          IconButton(onPressed: _refreshChildren, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChildRegistrationPage()),
          );
          if (result == true) _refreshChildren();
        },
        label: const Text('Register Child'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by Child ID, Name, or Parent...',
              leading: const Icon(Icons.search),
              onChanged: (val) {
                _searchQuery = val;
                _applyFilterAndSort();
              },
            ),
          ),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChildren.isEmpty
                    ? const Center(child: Text('No matching child records found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredChildren.length,
                        itemBuilder: (context, index) {
                          final child = _filteredChildren[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(child.firstName[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              title: Text('${child.firstName} ${child.lastName}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ID: ${child.childId}'),
                                  Text('Age: ${child.age} yrs | Gender: ${child.gender}'),
                                  Text('Parent: ${child.parentName}'),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => ChildRegistrationPage(child: child)),
                                      );
                                      if (result == true) _refreshChildren();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteChild(child),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, size: 18),
              const SizedBox(width: 8),
              const Text('Filter Gender:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Male', 'Female'].map((gender) {
                      final isSelected = _selectedGenderFilter == gender;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(gender == 'All' ? 'All Genders' : gender, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedGenderFilter = gender;
                                _applyFilterAndSort();
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sortBy,
                underline: const SizedBox(),
                icon: const Icon(Icons.sort, size: 20),
                items: ['Name A-Z', 'Name Z-A', 'Age (Youngest)', 'Age (Oldest)']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _sortBy = val;
                      _applyFilterAndSort();
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
