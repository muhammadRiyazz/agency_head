import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agency_head/core/theme/app_colors.dart';
import 'package:agency_head/core/network/api_service.dart';
import 'package:agency_head/core/models/api_spreadsheet_model.dart';
import 'package:agency_head/core/services/auth_service.dart';
import 'package:agency_head/core/responsive/responsive_layout.dart';

class SpreadsheetScreen extends StatefulWidget {
  final String sheetId;

  const SpreadsheetScreen({super.key, required this.sheetId});

  @override
  State<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends State<SpreadsheetScreen> {
  ApiSpreadsheet? _sheet;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _currentUser;
  bool _isTableView = false; // Manager defaults to Cards view; staff defaults to Table view
  String _searchQuery = '';
  String _selectedStatusFilter = 'all';

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  int get _sheetTotalCount {
    if (_sheet == null) return 0;
    return _sheet!.rows.where((r) => r.id > 0 || !r.leadName.startsWith('Lead #')).length;
  }

  int get _sheetNewCount {
    if (_sheet == null) return 0;
    return _sheet!.rows.where((r) => (r.id > 0 || !r.leadName.startsWith('Lead #')) && r.status.toLowerCase().contains('new')).length;
  }

  int get _sheetInProgressCount {
    if (_sheet == null) return 0;
    return _sheet!.rows.where((r) => (r.id > 0 || !r.leadName.startsWith('Lead #')) && (r.status.toLowerCase().contains('progress') || r.status.toLowerCase().contains('contacted'))).length;
  }

  int get _sheetClosedCount {
    if (_sheet == null) return 0;
    return _sheet!.rows.where((r) => (r.id > 0 || !r.leadName.startsWith('Lead #')) && (r.status.toLowerCase().contains('closed') || r.status.toLowerCase().contains('paid') || r.status.toLowerCase().contains('won'))).length;
  }

  int get _sheetTotalPipelineAmount {
    if (_sheet == null) return 0;
    int total = 0;
    for (var r in _sheet!.rows) {
      if (r.id <= 0 && r.leadName.startsWith('Lead #')) continue;
      final amt = r.data['Working Amount'] ?? r.data['working_amount'] ?? '';
      total += int.tryParse(amt.toString().replaceAll(',', '').replaceAll(' ', '').replaceAll('₹', '')) ?? 0;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final user = await AuthService.getUser();
    if (!mounted) return;

    final groupId = int.tryParse(user?['group_id']?.toString() ?? '0') ?? 0;
    final isStaffOrAccounts = (groupId == 4 || groupId == 5 || groupId == 2);

    setState(() {
      _currentUser = user;
      // Default view: Cards for Manager, Table for Staff & Accounts
      _isTableView = isStaffOrAccounts;
    });

    _fetchSheetData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  bool get _isManager {
    final groupId = int.tryParse(_currentUser?['group_id']?.toString() ?? '0') ?? 0;
    final groupName = (_currentUser?['group_name'] ?? '').toString().toLowerCase();
    return groupId == 6 || groupId == 1 || groupName.contains('manager') || groupName.contains('admin');
  }

  bool get _isExecutive {
    final groupId = int.tryParse(_currentUser?['group_id']?.toString() ?? '0') ?? 0;
    final groupName = (_currentUser?['group_name'] ?? '').toString().toLowerCase();
    return groupId == 4 || groupId == 5 || groupName.contains('executive') || groupName.contains('staff') || groupName.contains('feild') || groupName.contains('field');
  }

  bool get _isAccounts {
    final groupId = int.tryParse(_currentUser?['group_id']?.toString() ?? '0') ?? 0;
    final groupName = (_currentUser?['group_name'] ?? '').toString().toLowerCase();
    return groupId == 2 || groupName.contains('account');
  }

  int get _currentUserId {
    return int.tryParse(_currentUser?['id']?.toString() ?? '3') ?? 3;
  }

  String _getUserRoleString() {
    final groupId = int.tryParse(_currentUser?['group_id']?.toString() ?? '0') ?? 0;
    final groupName = (_currentUser?['group_name'] ?? '').toString().toLowerCase();
    if (groupId == 6 || groupId == 1 || groupName.contains('manager') || groupName.contains('admin')) {
      return 'Manager';
    }
    if (groupId == 4 || groupName.contains('feild') || groupName.contains('field')) {
      return 'Feild Executive';
    }
    if (groupId == 5 || groupName.contains('backend') || groupName.contains('office')) {
      return 'BackEnd Staff';
    }
    if (groupId == 2 || groupName.contains('account')) {
      return 'Accounts';
    }
    final rawName = (_currentUser?['group_name'] ?? '').toString();
    if (rawName.isNotEmpty) return rawName;
    return 'Manager';
  }

  Future<void> _fetchSheetData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final id = int.tryParse(widget.sheetId) ?? 1;
      final response = await ApiService.getSheetDetails(
        sheetId: id,
        userId: _currentUserId,
        role: _getUserRoleString(),
      );

      if (!mounted) return;
      if (response['status'] == true && response['data'] != null) {
        setState(() {
          _sheet = ApiSpreadsheet.fromJson(response['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load sheet details';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<ApiRow> get _filteredRows {
    if (_sheet == null) return [];
    return _sheet!.rows.where((row) {
      if (row.id <= 0 && row.leadName.startsWith('Lead #')) {
        // Skip padding dummy rows
        return false;
      }
      if (_selectedStatusFilter != 'all') {
        if (row.status.toLowerCase() != _selectedStatusFilter.toLowerCase()) {
          return false;
        }
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatches = row.leadName.toLowerCase().contains(q);
        final phoneMatches = row.phoneNumber.toLowerCase().contains(q);
        final countryMatches = row.country.toLowerCase().contains(q);
        final dataMatches = row.data.values.any((v) => v.toString().toLowerCase().contains(q));
        return nameMatches || phoneMatches || countryMatches || dataMatches;
      }
      return true;
    }).toList();
  }

  // =========================================================================
  // ADD LEAD TO SHEET (Manager Action - All Columns from API)
  // Endpoint: POST api/add_row
  // =========================================================================
  Future<void> _showAddLeadDialog() async {
    final List<ApiColumn> columns = (_sheet != null && _sheet!.columns.isNotEmpty)
        ? _sheet!.columns
        : [
            ApiColumn(id: 1, columnKey: 'col_1', columnName: 'Number', columnType: 'text', userType: 'common'),
            ApiColumn(id: 2, columnKey: 'col_2', columnName: 'Name', columnType: 'text', userType: 'common'),
            ApiColumn(id: 3, columnKey: 'col_3', columnName: 'Country', columnType: 'text', userType: 'common'),
            ApiColumn(id: 4, columnKey: 'col_4', columnName: 'Working Amount', columnType: 'number', userType: 'executive'),
            ApiColumn(id: 5, columnKey: 'col_5', columnName: 'Agency Name', columnType: 'text', userType: 'executive'),
            ApiColumn(id: 6, columnKey: 'col_6', columnName: 'Process Type', columnType: 'text', userType: 'executive'),
            ApiColumn(id: 7, columnKey: 'col_7', columnName: 'Percentage/ Service Charge', columnType: 'number', userType: 'executive'),
            ApiColumn(id: 8, columnKey: 'col_8', columnName: 'Bank', columnType: 'text', userType: 'executive'),
            ApiColumn(id: 9, columnKey: 'col_9', columnName: 'Own Work', columnType: 'text', userType: 'executive'),
            ApiColumn(id: 10, columnKey: 'col_10', columnName: 'Advance Paid/Not paid', columnType: 'text', userType: 'common'),
            ApiColumn(id: 11, columnKey: 'col_11', columnName: 'Bank Name/ Account Number', columnType: 'number', userType: 'executive'),
            ApiColumn(id: 12, columnKey: 'col_12', columnName: 'Cash in Hand', columnType: 'number', userType: 'executive'),
            ApiColumn(id: 13, columnKey: 'col_13', columnName: 'Total Credit Amount', columnType: 'number', userType: 'executive'),
            ApiColumn(id: 14, columnKey: 'col_14', columnName: 'Bank / Collected', columnType: 'text', userType: 'accounts'),
            ApiColumn(id: 15, columnKey: 'col_15', columnName: 'Company Payment', columnType: 'text', userType: 'accounts'),
            ApiColumn(id: 16, columnKey: 'col_16', columnName: 'Profit', columnType: 'text', userType: 'accounts'),
            ApiColumn(id: 17, columnKey: 'col_17', columnName: 'Agency Payment', columnType: 'text', userType: 'accounts'),
            ApiColumn(id: 18, columnKey: 'col_18', columnName: 'Status', columnType: 'dropdown', userType: 'common', options: ['paid', 'unpaid', 'new', 'in_progress', 'closed']),
          ];

    final Map<String, TextEditingController> colControllers = {};
    for (var col in columns) {
      colControllers[col.columnName] = TextEditingController();
    }

    String status = 'new';
    int? selectedAssignedTo;
    List<Map<String, dynamic>> staffList = [];
    bool isStaffLoading = true;
    bool isSubmitting = false;
    String? formError;

    // Fetch staff for optional assignment
    ApiService.getStaff().then((res) {
      if (res['status'] == true && res['data'] != null) {
        staffList = List<Map<String, dynamic>>.from(res['data']).where((s) {
          final gId = int.tryParse(s['group_id']?.toString() ?? '0') ?? 0;
          return gId == 4 || gId == 5;
        }).toList();
      }
      isStaffLoading = false;
    }).catchError((_) {
      isStaffLoading = false;
    });

    final commonCols = columns.where((c) => c.isCommon && c.columnName.toLowerCase() != 'status').toList();
    final executiveCols = columns.where((c) => c.isExecutive).toList();
    final accountsCols = columns.where((c) => c.isAccounts).toList();
    final customCols = columns.where((c) => !c.isCommon && !c.isExecutive && !c.isAccounts && c.columnName.toLowerCase() != 'status').toList();

    await showDialog(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final dialogWidth = screenWidth > 780 ? 700.0 : screenWidth * 0.95;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Widget buildFieldInput(ApiColumn col) {
              final ctrl = colControllers[col.columnName]!;
              final colLower = col.columnName.toLowerCase();
              final isRequired = colLower == 'name' || colLower == 'number' || colLower == 'candidate name' || colLower == 'phone number';

              IconData icon;
              if (colLower.contains('phone') || colLower == 'number') {
                icon = Icons.phone_outlined;
              } else if (colLower.contains('name') && !colLower.contains('agency')) {
                icon = Icons.person_outline;
              } else if (colLower.contains('country')) {
                icon = Icons.public;
              } else if (colLower.contains('amount') || colLower.contains('profit') || colLower.contains('payment') || colLower.contains('charge') || colLower.contains('cash') || colLower.contains('credit')) {
                icon = Icons.currency_rupee;
              } else if (colLower.contains('agency')) {
                icon = Icons.business_outlined;
              } else if (colLower.contains('bank')) {
                icon = Icons.account_balance_outlined;
              } else if (colLower.contains('work') || colLower.contains('process')) {
                icon = Icons.work_outline;
              } else {
                icon = Icons.edit_note_rounded;
              }

              final isNumber = col.columnType == 'number' ||
                  colLower.contains('amount') ||
                  colLower.contains('charge') ||
                  colLower.contains('profit') ||
                  colLower.contains('credit') ||
                  colLower.contains('cash') ||
                  colLower == 'number';

              if (col.options != null && col.options!.isNotEmpty) {
                return DropdownButtonFormField<String>(
                  value: col.options!.contains(ctrl.text) ? ctrl.text : null,
                  decoration: InputDecoration(
                    labelText: col.columnName + (isRequired ? ' *' : ''),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    prefixIcon: Icon(icon, size: 18),
                    isDense: true,
                  ),
                  items: col.options!.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => ctrl.text = val);
                  },
                );
              }

              return TextFormField(
                controller: ctrl,
                keyboardType: isNumber ? TextInputType.number : TextInputType.text,
                decoration: InputDecoration(
                  labelText: col.columnName + (isRequired ? ' *' : ''),
                  hintText: 'Enter ${col.columnName}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  prefixIcon: Icon(icon, size: 18),
                  isDense: true,
                ),
              );
            }

            Widget buildSectionHeader(String title, IconData icon, Color color, int count) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                    ),
                    const Spacer(),
                    Text(
                      '$count fields',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              );
            }

            Widget buildFieldsGrid(List<ApiColumn> cols) {
              final isWide = dialogWidth > 580;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: cols.map((col) {
                      return SizedBox(
                        width: itemWidth,
                        child: buildFieldInput(col),
                      );
                    }).toList(),
                  );
                },
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add Lead to Sheet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        Text(
                          'Populate all sheet fields for "${_sheet?.title ?? 'this sheet'}"',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: dialogWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (formError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(formError!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 1. General Lead Information
                        if (commonCols.isNotEmpty) ...[
                          buildSectionHeader('General Lead Information', Icons.person_outline, const Color(0xFF3B82F6), commonCols.length),
                          const SizedBox(height: 10),
                          buildFieldsGrid(commonCols),
                          const SizedBox(height: 16),
                        ],

                        // 2. Executive Details
                        if (executiveCols.isNotEmpty) ...[
                          buildSectionHeader('Executive Details', Icons.work_outline_rounded, const Color(0xFFF59E0B), executiveCols.length),
                          const SizedBox(height: 10),
                          buildFieldsGrid(executiveCols),
                          const SizedBox(height: 16),
                        ],

                        // 3. Accounts Details
                        if (accountsCols.isNotEmpty) ...[
                          buildSectionHeader('Accounts & Financials', Icons.account_balance_wallet_outlined, const Color(0xFF10B981), accountsCols.length),
                          const SizedBox(height: 10),
                          buildFieldsGrid(accountsCols),
                          const SizedBox(height: 16),
                        ],

                        // 4. Custom Columns (if any)
                        if (customCols.isNotEmpty) ...[
                          buildSectionHeader('Custom Columns', Icons.view_column_rounded, const Color(0xFF8B5CF6), customCols.length),
                          const SizedBox(height: 10),
                          buildFieldsGrid(customCols),
                          const SizedBox(height: 16),
                        ],

                        // 5. Lead Status & Assignment
                        buildSectionHeader('Lead Status & Assignment', Icons.assignment_ind_outlined, const Color(0xFF64748B), 2),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: status,
                                decoration: InputDecoration(
                                  labelText: 'Lead Status',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.flag_outlined, size: 18),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'new', child: Text('New')),
                                  DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                                  DropdownMenuItem(value: 'contacted', child: Text('Contacted')),
                                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                                  DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => status = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int?>(
                                value: selectedAssignedTo,
                                decoration: InputDecoration(
                                  labelText: 'Assign to Staff (Optional)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(value: null, child: Text('Unassigned (Pool)')),
                                  ...staffList.map((s) {
                                    final sId = int.tryParse(s['id'].toString()) ?? 0;
                                    final sName = s['name'] ?? 'Staff';
                                    final sRole = s['group_name'] ?? 'Executive';
                                    return DropdownMenuItem<int?>(value: sId, child: Text('$sName ($sRole)'));
                                  }),
                                ],
                                onChanged: (val) {
                                  setDialogState(() => selectedAssignedTo = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          // Validate Name and Phone
                          String candidateName = '';
                          String phoneNumber = '';

                          for (var col in columns) {
                            final colLower = col.columnName.toLowerCase();
                            if (colLower == 'name' || colLower == 'candidate name') {
                              candidateName = colControllers[col.columnName]?.text.trim() ?? '';
                            } else if (colLower == 'number' || colLower == 'phone' || colLower == 'phone number') {
                              phoneNumber = colControllers[col.columnName]?.text.trim() ?? '';
                            }
                          }

                          if (candidateName.isEmpty || phoneNumber.isEmpty) {
                            setDialogState(() {
                              formError = 'Candidate Name and Phone Number are required.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            formError = null;
                          });

                          try {
                            final sheetId = int.tryParse(widget.sheetId) ?? 1;

                            // Build payload with every column value mapped to both key and name
                            final dataPayload = <String, dynamic>{};
                            for (var col in columns) {
                              final text = colControllers[col.columnName]?.text.trim() ?? '';
                              dataPayload[col.columnName] = text;
                              if (col.columnKey.isNotEmpty) {
                                dataPayload[col.columnKey] = text;
                              }
                            }

                            // Explicit standard keys
                            dataPayload['Name'] = candidateName;
                            dataPayload['Number'] = phoneNumber;
                            dataPayload['Status'] = status;

                            final response = await ApiService.addRow(
                              sheetId: sheetId,
                              createdBy: _currentUserId,
                              assignedTo: selectedAssignedTo,
                              status: status,
                              data: dataPayload,
                            );

                            if (!dialogContext.mounted) return;

                            if (response['status'] == true) {
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Lead added successfully with all details!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              _fetchSheetData();
                            } else {
                              setDialogState(() {
                                isSubmitting = false;
                                formError = response['message'] ?? 'Failed to add lead.';
                              });
                            }
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isSubmitting = false;
                              formError = e.toString();
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add Lead'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // ADD NEW COLUMN TO SHEET (Manager Action - Section 1.3)
  // Endpoint: POST api/add_column
  // =========================================================================
  Future<void> _showAddColumnDialog() async {
    final colNameController = TextEditingController();
    String colType = 'text';
    final optionsController = TextEditingController();
    bool isSubmitting = false;
    String? formError;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.view_column_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Add Custom Column', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add a new custom column to this sheet beyond the 18 master fields.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      if (formError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(formError!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: colNameController,
                        decoration: InputDecoration(
                          labelText: 'Column Name *',
                          hintText: 'e.g. Passport Status, Remarks',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: colType,
                        decoration: InputDecoration(
                          labelText: 'Column Type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'text', child: Text('Text')),
                          DropdownMenuItem(value: 'number', child: Text('Number')),
                          DropdownMenuItem(value: 'dropdown', child: Text('Dropdown')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => colType = val);
                        },
                      ),
                      if (colType == 'dropdown') ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: optionsController,
                          decoration: InputDecoration(
                            labelText: 'Dropdown Options (comma-separated)',
                            hintText: 'e.g. Yes, No, Pending',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = colNameController.text.trim();
                          if (name.isEmpty) {
                            setDialogState(() => formError = 'Column Name is required.');
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            formError = null;
                          });

                          try {
                            final sheetId = int.tryParse(widget.sheetId) ?? 1;
                            List<String>? opts;
                            if (colType == 'dropdown' && optionsController.text.trim().isNotEmpty) {
                              opts = optionsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                            }

                            final res = await ApiService.addColumn(
                              sheetId: sheetId,
                              columnName: name,
                              columnType: colType,
                              options: opts,
                            );

                            if (!dialogContext.mounted) return;
                            if (res['status'] == true) {
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Column added successfully!'), backgroundColor: AppColors.success),
                              );
                              _fetchSheetData();
                            } else {
                              setDialogState(() {
                                isSubmitting = false;
                                formError = res['message'] ?? 'Failed to add column.';
                              });
                            }
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isSubmitting = false;
                              formError = e.toString();
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add Column'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // ASSIGN SHEET TO FIELD/OFFICE EXECUTIVE (Manager Action)
  // Endpoint: POST api/assign_sheet
  // =========================================================================
  Future<void> _showAssignToStaffDialog() async {
    List<Map<String, dynamic>> staffList = [];
    bool isStaffLoading = true;
    String? staffError;
    int? selectedUserId;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            if (staffList.isEmpty && isStaffLoading && staffError == null) {
              ApiService.getStaff().then((res) {
                if (dialogContext.mounted) {
                  if (res['status'] == true && res['data'] != null) {
                    final allStaff = List<Map<String, dynamic>>.from(res['data']);
                    // Filter for Field Executives (group 4) and Office Staff (group 5)
                    final execs = allStaff.where((s) {
                      final gId = int.tryParse(s['group_id']?.toString() ?? '0') ?? 0;
                      return gId == 4 || gId == 5;
                    }).toList();

                    setDialogState(() {
                      staffList = execs.isNotEmpty ? execs : allStaff;
                      isStaffLoading = false;
                      if (staffList.isNotEmpty) {
                        selectedUserId = int.tryParse(staffList.first['id'].toString());
                      }
                    });
                  } else {
                    setDialogState(() {
                      staffError = res['message'] ?? 'Unable to load staff';
                      isStaffLoading = false;
                    });
                  }
                }
              }).catchError((err) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    staffError = err.toString();
                    isStaffLoading = false;
                  });
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Assign Sheet to Staff', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: isStaffLoading
                    ? const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : staffError != null
                        ? Text(staffError!, style: const TextStyle(color: AppColors.error))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select a Field Executive or Office Executive to take ownership of all leads in "${_sheet?.title}".',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 18),
                              DropdownButtonFormField<int>(
                                initialValue: selectedUserId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Select Executive',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                ),
                                items: staffList.map((staff) {
                                  final name = staff['name'] ?? 'Staff';
                                  final group = staff['group_name'] ?? 'Executive';
                                  final id = int.tryParse(staff['id'].toString()) ?? 0;
                                  return DropdownMenuItem<int>(
                                    value: id,
                                    child: Text('$name ($group)'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setDialogState(() => selectedUserId = val);
                                },
                              ),
                            ],
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedUserId == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          _assignStaff(selectedUserId!);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Assign Sheet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _assignStaff(int staffUserId) async {
    try {
      final sheetId = int.tryParse(widget.sheetId) ?? 1;
      final response = await ApiService.assignSheetToStaff(
        sheetId: sheetId,
        userId: staffUserId,
        assignedBy: _currentUserId,
      );

      if (!mounted) return;
      if (response['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Sheet successfully assigned to staff.'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchSheetData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Assignment failed.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // =========================================================================
  // ASSIGN SHEET TO ACCOUNTS (Accounts Staff: group_id = 2)
  // Endpoint: GET api/get_staff?group_id=2 (or ?group_id=2&status=1)
  // Endpoint: POST api/assign_to_accounts
  // =========================================================================
  ApiAssignedUser? get _assignedAccountsUser {
    if (_sheet == null) return null;
    try {
      return _sheet!.assignedUsers.firstWhere(
        (u) => u.groupId == 2 || u.groupName.toLowerCase().contains('account'),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _showAssignToAccountsDialog() async {
    List<Map<String, dynamic>> accountsList = [];
    bool isLoadingStaff = true;
    String? accountsError;
    int? selectedAccountsId;

    final currentAssignedAccount = _assignedAccountsUser;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            if (accountsList.isEmpty && isLoadingStaff && accountsError == null) {
              // Group ID 2 is strictly for Accounts Staff as per API documentation:
              // Endpoint: GET api/get_staff?group_id=2&status=1
              ApiService.getStaff(groupId: 2, status: 1).then((res) {
                if (dialogContext.mounted) {
                  List<Map<String, dynamic>> rawList = [];
                  if (res['status'] == true && res['data'] != null && (res['data'] as List).isNotEmpty) {
                    rawList = List<Map<String, dynamic>>.from(res['data']);
                  }

                  // Strictly filter: ONLY users where group_id == 2 (Accounts Staff)
                  final accountsOnly = rawList.where((s) {
                    final gId = int.tryParse(s['group_id']?.toString() ?? '0') ?? 0;
                    return gId == 2;
                  }).toList();

                  if (accountsOnly.isNotEmpty) {
                    setDialogState(() {
                      accountsList = accountsOnly;
                      isLoadingStaff = false;
                      if (currentAssignedAccount != null &&
                          accountsList.any((a) => a['id'].toString() == currentAssignedAccount.userId.toString())) {
                        selectedAccountsId = currentAssignedAccount.userId;
                      } else {
                        selectedAccountsId = int.tryParse(accountsList.first['id'].toString());
                      }
                    });
                  } else {
                    // Fallback to fetch all group_id=2 (unfiltered status in case inactive or status != 1)
                    ApiService.getStaff(groupId: 2).then((fallbackRes) {
                      if (dialogContext.mounted) {
                        List<Map<String, dynamic>> fallbackRaw = [];
                        if (fallbackRes['status'] == true &&
                            fallbackRes['data'] != null &&
                            (fallbackRes['data'] as List).isNotEmpty) {
                          fallbackRaw = List<Map<String, dynamic>>.from(fallbackRes['data']);
                        }

                        // Strictly filter: ONLY users where group_id == 2
                        final fallbackAccountsOnly = fallbackRaw.where((s) {
                          final gId = int.tryParse(s['group_id']?.toString() ?? '0') ?? 0;
                          return gId == 2;
                        }).toList();

                        if (fallbackAccountsOnly.isNotEmpty) {
                          setDialogState(() {
                            accountsList = fallbackAccountsOnly;
                            isLoadingStaff = false;
                            if (currentAssignedAccount != null &&
                                accountsList.any((a) => a['id'].toString() == currentAssignedAccount.userId.toString())) {
                              selectedAccountsId = currentAssignedAccount.userId;
                            } else {
                              selectedAccountsId = int.tryParse(accountsList.first['id'].toString());
                            }
                          });
                        } else {
                          setDialogState(() {
                            accountsError = 'No Accounts staff found in system (group_id=2).';
                            isLoadingStaff = false;
                          });
                        }
                      }
                    }).catchError((err) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          accountsError = err.toString();
                          isLoadingStaff = false;
                        });
                      }
                    });
                  }
                }
              }).catchError((err) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    accountsError = err.toString();
                    isLoadingStaff = false;
                  });
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: AppColors.success),
                  SizedBox(width: 10),
                  Text('Assign to Accounts Staff', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: isLoadingStaff
                    ? const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : accountsError != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: AppColors.error),
                                const SizedBox(width: 10),
                                Expanded(child: Text(accountsError!, style: const TextStyle(color: AppColors.error))),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assign "${_sheet?.title}" to an Accounts staff member (Group 2) for verification, payment tracking, and ledger entries.',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              if (currentAssignedAccount != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Currently Assigned: ${currentAssignedAccount.name} (${currentAssignedAccount.email.isNotEmpty ? currentAssignedAccount.email : 'Accounts'})',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              DropdownButtonFormField<int>(
                                initialValue: selectedAccountsId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Select Accounts Staff (Group 2)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                ),
                                items: accountsList.map((acc) {
                                  final name = acc['name'] ?? 'Accounts User';
                                  final email = acc['email'] ?? '';
                                  final id = int.tryParse(acc['id'].toString()) ?? 0;
                                  return DropdownMenuItem<int>(
                                    value: id,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: AppColors.success.withValues(alpha: 0.15),
                                          child: Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            email.isNotEmpty ? '$name ($email)' : name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setDialogState(() => selectedAccountsId = val);
                                },
                              ),
                            ],
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedAccountsId == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          _assignAccounts(selectedAccountsId!);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(currentAssignedAccount != null ? 'Update Accounts' : 'Assign to Accounts'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _assignAccounts(int accountsUserId) async {
    try {
      final sheetId = int.tryParse(widget.sheetId) ?? 1;
      final response = await ApiService.assignSheetToAccounts(
        sheetId: sheetId,
        accountsUserId: accountsUserId,
        assignedBy: _currentUserId,
      );

      if (!mounted) return;
      if (response['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Sheet successfully assigned to Accounts staff.'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchSheetData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Accounts assignment failed.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // =========================================================================
  // NAVIGATE TO FULL LEAD DETAILS PAGE
  // =========================================================================
  Future<void> _openLeadDetailsPage(ApiRow row, {bool editMode = false}) async {
    final result = await context.push(
      '/sheet/${widget.sheetId}/lead/${row.id}',
      extra: {
        'row': row,
        'sheet': _sheet,
        'sheetId': widget.sheetId,
        'userRole': _getUserRoleString(),
        'editMode': editMode,
      },
    );
    if (result == true || mounted) {
      _fetchSheetData();
    }
  }

  // =========================================================================
  // EDIT LEAD DETAILS (Redirects to Full Lead Details Page in Edit Mode)
  // Ensures NO dialog modal opens; full dedicated page is used!
  // =========================================================================
  Future<void> _showLeadDetailsDialog(ApiRow row) async {
    await _openLeadDetailsPage(row, editMode: true);
  }
  // =========================================================================
  // MAIN BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sheet?.title ?? 'Sheet #${widget.sheetId}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (_sheet != null && _sheet!.description.isNotEmpty)
              Text(
                _sheet!.description,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: isDesktop
            ? [
                // DESKTOP WIDESCREEN ACTIONS (100% UNCHANGED)
                // Toggle View Button (Cards vs Table)
                IconButton(
                  tooltip: _isTableView ? 'Switch to Cards View' : 'Switch to Table View',
                  icon: Icon(
                    _isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _isTableView = !_isTableView;
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
                  onPressed: _fetchSheetData,
                ),
                if (_isManager) ...[
                  // Manager: Add Lead to Sheet (POST api/add_row)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: ElevatedButton.icon(
                      onPressed: _showAddLeadDialog,
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: const Text('Add Lead', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  // Manager: Assign to Staff
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: OutlinedButton.icon(
                      onPressed: _showAssignToStaffDialog,
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                      label: const Text('Assign Staff', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],

                // Accounts Assignment Indicator & Action (Manager or Executive)
                if (_assignedAccountsUser != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 12.0),
                    child: InkWell(
                      onTap: (_isManager || _isExecutive) ? _showAssignToAccountsDialog : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded, size: 15, color: Color(0xFF059669)),
                            const SizedBox(width: 6),
                            Text(
                              'Accounts: ${_assignedAccountsUser!.name}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                            ),
                            if (_isManager || _isExecutive) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF059669)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  if (_isManager)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 12.0),
                      child: OutlinedButton.icon(
                        onPressed: _showAssignToAccountsDialog,
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                        label: const Text('Assign Accounts', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: const BorderSide(color: AppColors.success),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    )
                  else if (_isExecutive)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 12.0),
                      child: ElevatedButton.icon(
                        onPressed: _showAssignToAccountsDialog,
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Send to Accounts', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                ],
              ]
            : [
                // MOBILE ADAPTIVE CLEAN ACTIONS (ZERO OVERFLOW)
                IconButton(
                  tooltip: _isTableView ? 'Switch to Cards' : 'Switch to Table',
                  icon: Icon(
                    _isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() {
                      _isTableView = !_isTableView;
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary, size: 22),
                  onPressed: _fetchSheetData,
                ),
                if (_isManager || _isExecutive)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary, size: 22),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val == 'add_lead') _showAddLeadDialog();
                      if (val == 'assign_staff') _showAssignToStaffDialog();
                      if (val == 'assign_accounts') _showAssignToAccountsDialog();
                    },
                    itemBuilder: (ctx) => [
                      if (_isManager) ...[
                        const PopupMenuItem(
                          value: 'add_lead',
                          child: Row(
                            children: [
                              Icon(Icons.person_add_rounded, size: 18, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text('Add Lead', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'assign_staff',
                          child: Row(
                            children: [
                              Icon(Icons.person_add_alt_1_outlined, size: 18, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text('Assign Staff', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      if (_isManager || _isExecutive)
                        PopupMenuItem(
                          value: 'assign_accounts',
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 18, color: Color(0xFF059669)),
                              const SizedBox(width: 10),
                              Text(
                                _assignedAccountsUser != null
                                    ? 'Accounts: ${_assignedAccountsUser!.name}'
                                    : 'Assign Accounts',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchSheetData,
                          child: const Text('Retry Loading'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (isDesktop) ...[
                      // Top Sheet KPI Dashboard Overview (Counts & Metrics on Desktop)
                      _buildSheetStatsOverview(isDesktop),

                      // Desktop Search & Filter Bar (Side-by-side)
                      _buildDesktopSearchFilterBar(),
                    ] else ...[
                      // Mobile Adaptive Search & Filter Section (Full-width search + counts chips)
                      _buildMobileTopSection(),
                    ],

                    // Main View (Cards View or Excel Table View)
                    Expanded(
                      child: _isTableView
                          ? _buildExcelTableView()
                          : _buildManagerCardsView(isDesktop),
                    ),
                  ],
                ),
      floatingActionButton: _isManager
          ? FloatingActionButton.extended(
              onPressed: _showAddLeadDialog,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Lead'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  // =========================================================================
  // DESKTOP SEARCH & FILTER BAR (Widescreen Side-by-side, 100% UNCHANGED)
  // =========================================================================
  Widget _buildDesktopSearchFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search leads in this sheet...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          const SizedBox(width: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('All', 'all'),
                const SizedBox(width: 6),
                _buildStatusChip('New', 'new'),
                const SizedBox(width: 6),
                _buildStatusChip('In Progress', 'in_progress'),
                const SizedBox(width: 6),
                _buildStatusChip('Closed', 'closed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MOBILE TOP SECTION (Full-Width Search + Scrollable Status Count Chips)
  // Clean, zero squishing, zero overflow, native mobile app presentation!
  // =========================================================================
  Widget _buildMobileTopSection() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accounts Assigned Banner (if sheet is assigned to accounts)
          if (_assignedAccountsUser != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assigned to Accounts: ${_assignedAccountsUser!.name}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isManager || _isExecutive)
                    GestureDetector(
                      onTap: _showAssignToAccountsDialog,
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Full-width Search Input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search leads in this sheet...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),

          // Horizontal Filter Chips with Status Counts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _buildMobileStatusChip(
                  label: 'All',
                  value: 'all',
                  count: _sheetTotalCount,
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 8),
                _buildMobileStatusChip(
                  label: 'New',
                  value: 'new',
                  count: _sheetNewCount,
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                _buildMobileStatusChip(
                  label: 'In Progress',
                  value: 'in_progress',
                  count: _sheetInProgressCount,
                  color: const Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 8),
                _buildMobileStatusChip(
                  label: 'Closed',
                  value: 'closed',
                  count: _sheetClosedCount,
                  color: const Color(0xFF10B981),
                ),
                if (_sheetTotalPipelineAmount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.currency_rupee_rounded, size: 13, color: Color(0xFF0369A1)),
                        const SizedBox(width: 2),
                        Text(
                          '₹$_sheetTotalPipelineAmount Pipeline',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatusChip({
    required String label,
    required String value,
    required int count,
    required Color color,
  }) {
    final isSelected = _selectedStatusFilter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedStatusFilter = value);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFCBD5E1),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary),
      checkmarkColor: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatusFilter = value);
        }
      },
    );
  }

  // =========================================================================
  // TOP SHEET KPI DASHBOARD OVERVIEW (Counts & Metrics on Desktop)
  // =========================================================================
  Widget _buildSheetStatsOverview(bool isDesktop) {
    if (_sheet == null) return const SizedBox();

    final statItems = [
      _buildSheetStatCard(
        label: 'Total Leads',
        count: _sheetTotalCount.toString(),
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF3B82F6),
        filterKey: 'all',
      ),
      _buildSheetStatCard(
        label: 'New Leads',
        count: _sheetNewCount.toString(),
        icon: Icons.fiber_new_rounded,
        color: const Color(0xFFF59E0B),
        filterKey: 'new',
      ),
      _buildSheetStatCard(
        label: 'In Progress',
        count: _sheetInProgressCount.toString(),
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF8B5CF6),
        filterKey: 'in_progress',
      ),
      _buildSheetStatCard(
        label: 'Closed / Paid',
        count: _sheetClosedCount.toString(),
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF10B981),
        filterKey: 'closed',
      ),
      if (_sheetTotalPipelineAmount > 0)
        _buildSheetStatCard(
          label: 'Total Pipeline',
          count: '₹$_sheetTotalPipelineAmount',
          icon: Icons.currency_rupee_rounded,
          color: const Color(0xFF0EA5E9),
          filterKey: null,
        ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 12,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: isDesktop
          ? Row(
              children: statItems.map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: c,
                ),
              )).toList(),
            )
          : SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: statItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => SizedBox(width: 150, child: statItems[i]),
              ),
            ),
    );
  }

  Widget _buildSheetStatCard({
    required String label,
    required String count,
    required IconData icon,
    required Color color,
    String? filterKey,
  }) {
    final isSelected = filterKey != null && _selectedStatusFilter == filterKey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: filterKey != null
            ? () {
                setState(() => _selectedStatusFilter = filterKey);
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? color.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.02),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? color : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // VIEW A: MANAGER BOX / CARDS VIEW (Clean, Modern, Box-Style Lead Cards)
  // =========================================================================
  Widget _buildManagerCardsView(bool isDesktop) {
    final rows = _filteredRows;

    if (rows.isEmpty) {
      final hasActiveFilter = _searchQuery.trim().isNotEmpty || _selectedStatusFilter != 'all';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasActiveFilter ? Icons.search_off_rounded : Icons.inbox_outlined,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                hasActiveFilter
                    ? (_searchQuery.trim().isNotEmpty
                        ? 'No leads matching "$_searchQuery"'
                        : 'No leads with status "$_selectedStatusFilter"')
                    : 'No leads matching criteria',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                hasActiveFilter ? 'Try clearing filters or search query.' : 'Try clearing search filters or add new leads.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (hasActiveFilter) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                      _selectedStatusFilter = 'all';
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Clear All Filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
              if (_isManager) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _showAddLeadDialog,
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add Candidate Lead'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ResponsiveContainer(
      maxWidth: 1200,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 16,
      ),
      child: isDesktop
          ? GridView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveLayout.getGridCrossAxisCount(context, mobile: 1, tablet: 2, desktop: 3),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 180,
              ),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                return _buildLeadCard(rows[index]);
              },
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 40),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildLeadCard(rows[index]);
              },
            ),
    );
  }

  Widget _buildLeadCard(ApiRow row) {
    final leadName = row.leadName;
    final phone = row.phoneNumber;
    final country = row.country;
    final status = row.status;

    // Optional executive & accounts fields preview
    final workingAmount = row.data['Working Amount'] ?? row.data['working_amount'] ?? '';
    final agencyName = row.data['Agency Name'] ?? row.data['agency_name'] ?? '';

    Color statusColor;
    if (status.toLowerCase().contains('new')) {
      statusColor = const Color(0xFF3B82F6);
    } else if (status.toLowerCase().contains('progress')) {
      statusColor = const Color(0xFFF59E0B);
    } else if (status.toLowerCase().contains('closed') || status.toLowerCase().contains('won')) {
      statusColor = AppColors.success;
    } else {
      statusColor = const Color(0xFF64748B);
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openLeadDetailsPage(row),
        borderRadius: BorderRadius.circular(16),
        hoverColor: AppColors.primary.withValues(alpha: 0.03),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Initials avatar + Name + Status Pill
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      leadName.isNotEmpty ? leadName.substring(0, 1).toUpperCase() : 'L',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          leadName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 10.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Country + Working Amount tags
              Row(
                children: [
                  if (country.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.public_rounded, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(country, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (workingAmount.toString().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '₹$workingAmount',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309), fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (agencyName.toString().isNotEmpty)
                    Expanded(
                      child: Text(
                        agencyName.toString(),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Row 3: Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lead #${row.id} • Row ${row.rowIndex}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _openLeadDetailsPage(row, editMode: true),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text('Edit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _openLeadDetailsPage(row, editMode: false),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Full Details', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // VIEW B: EXCEL SPREADSHEET TABLE GRID (Staff & Accounts Role-Filtered)
  // =========================================================================
  Widget _buildExcelTableView() {
    final rows = _filteredRows;
    final cols = _sheet!.columns;

    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        notificationPredicate: (notif) => notif.depth == 1,
        child: SingleChildScrollView(
          controller: _verticalController,
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              dataRowMinHeight: 46,
              dataRowMaxHeight: 52,
              columns: [
                const DataColumn(
                  label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                ...cols.map((col) {
                  Color tagColor;
                  if (col.isAccounts) {
                    tagColor = const Color(0xFF10B981);
                  } else if (col.isExecutive) {
                    tagColor = const Color(0xFFF59E0B);
                  } else {
                    tagColor = const Color(0xFF3B82F6);
                  }

                  return DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          col.columnName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            col.userType.toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: tagColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const DataColumn(
                  label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
              rows: rows.asMap().entries.map((entry) {
                final idx = entry.key;
                final row = entry.value;

                return DataRow(
                  cells: [
                    DataCell(Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ...cols.map((col) {
                      final val = row.getValue(col);
                      return DataCell(
                        Text(
                          val.isNotEmpty ? val : '—',
                          style: TextStyle(
                            fontSize: 13,
                            color: val.isNotEmpty ? AppColors.textPrimary : const Color(0xFF94A3B8),
                          ),
                        ),
                        onTap: () => _openLeadDetailsPage(row),
                      );
                    }),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.primary),
                            onPressed: () => _openLeadDetailsPage(row, editMode: false),
                            tooltip: 'View Full Lead Details',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.primary),
                            onPressed: () => _openLeadDetailsPage(row, editMode: true),
                            tooltip: 'Edit Lead (Full Page)',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
