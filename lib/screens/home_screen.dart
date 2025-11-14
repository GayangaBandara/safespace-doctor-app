import 'package:flutter/material.dart';
import '../authentication/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _displayName;
  bool _loading = true;
  bool _isAvailable = false;
  String? _userId;
  int? _doctorId;

  // Appointment data
  List<dynamic> _acceptedAppointments = [];
  List<dynamic> _pendingRequests = [];
  
  // Variables for date and time selection
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _initUser();
    _setupAutoRefresh();
  }

  void _setupAutoRefresh() {
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        setState(() {});
        _setupAutoRefresh();
      }
    });
  }

  Future<void> _initUser() async {
    setState(() {
      _loading = true;
    });

    try {
      final uid = _authService.getCurrentUserId();
      _userId = uid;

      final name = await _authService.fetchDisplayName();

      // Fetch doctor's availability status and ID
      final user = _supabase.auth.currentUser;
      if (user?.email != null) {
        final doctorData = await _supabase
            .from('doctors')
            .select('avb_status, id')
            .eq('email', user!.email!)
            .single();

        setState(() {
          _displayName = name;
          _isAvailable = doctorData['avb_status'] ?? false;
          _doctorId = doctorData['id'];
        });

        // Load appointments data
        await _loadAppointments();
        await _loadPendingRequests();
      } else {
        setState(() {
          _displayName = name;
        });
      }
    } catch (e, st) {
      debugPrint('Error initializing user: $e\n$st');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadAppointments() async {
    try {
      if (_doctorId == null) return;

      final appointmentsResponse = await _supabase
          .from('appointments')
          .select('*')
          .eq('doctor_id', _doctorId!)
          .order('date', ascending: true);

      setState(() {
        _acceptedAppointments = appointmentsResponse;
      });
    } catch (e) {
      debugPrint('Error loading appointments: $e');
      setState(() {
        _acceptedAppointments = [];
      });
    }
  }

  Future<void> _loadPendingRequests() async {
    try {
      if (_doctorId == null) return;

      final callRequestsResponse = await _supabase
          .from('call_requests')
          .select('id, user_id, username, email, created_at, status')
          .eq('doctor_id', _doctorId!)
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      // Map username to user_name for consistency
      final mappedRequests = callRequestsResponse.map((request) {
        final mappedRequest = Map<String, dynamic>.from(request);
        if (!mappedRequest.containsKey('user_name') &&
            mappedRequest.containsKey('username')) {
          mappedRequest['user_name'] = mappedRequest['username'];
        }
        return mappedRequest;
      }).toList();

      setState(() {
        _pendingRequests = mappedRequests;
      });
    } catch (e) {
      debugPrint('Error loading pending requests: $e');
      setState(() {
        _pendingRequests = [];
      });
    }
  }

  Future<void> _toggleAvailability() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user?.email == null) return;

      final newStatus = !_isAvailable;

      // Update the database
      await _supabase
          .from('doctors')
          .update({'avb_status': newStatus})
          .eq('email', user!.email!);

      // Update local state
      setState(() {
        _isAvailable = newStatus;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  newStatus
                      ? 'You are now available'
                      : 'You are now unavailable',
                ),
              ],
            ),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update availability status: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String get _greeting {
    if (_loading) return 'Hello Doctor 👋';
    if (_displayName != null && _displayName!.isNotEmpty) {
      final name = _displayName!.trim();
      if (name.toLowerCase().startsWith('dr') ||
          name.toLowerCase().startsWith('doctor')) {
        return 'Hello $name 👋';
      }
      return 'Hello Dr. $name 👋';
    }
    return 'Hello Doctor 👋';
  }

  // Appointment related methods
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _showScheduleDialog(Map<String, dynamic> request) {
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Schedule Appointment for ${request['user_name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Select Date'),
                    subtitle: Text(
                      _selectedDate != null
                          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                          : 'No date selected',
                    ),
                    onTap: () => _selectDate(context).then((_) {
                      setState(() {});
                    }),
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Select Time'),
                    subtitle: Text(
                      _selectedTime != null
                          ? _selectedTime!.format(context)
                          : 'No time selected',
                    ),
                    onTap: () => _selectTime(context).then((_) {
                      setState(() {});
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (_selectedDate != null && _selectedTime != null)
                      ? () {
                          Navigator.of(context).pop();
                          _acceptRequest(request);
                        }
                      : null,
                  child: const Text('Confirm Appointment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    if (_doctorId == null ||
        _selectedDate == null ||
        _selectedTime == null ||
        request['user_id'] == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Missing required data for scheduling'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final dateStr =
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00';

      final userName =
          request['user_name']?.toString() ??
          request['username']?.toString() ??
          'Unknown Patient';
      final roomName = _generateRoomName(userName);

      // Insert appointment
      await _supabase.from('appointments').insert({
        'doctor_id': _doctorId,
        'user_id': request['user_id'],
        'user_name': userName,
        'date': dateStr,
        'time': timeStr,
        'meeting_room': roomName,
        'status': 'confirmed',
      });

      // Handle patient record
      await _handlePatientRecord(request, dateStr, timeStr);

      // Remove from call requests
      await _removeFromCallRequests(request);

      // Reset selections
      _selectedDate = null;
      _selectedTime = null;

      // Refresh data
      await _loadAppointments();
      await _loadPendingRequests();

      // Success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment scheduled successfully for $userName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePatientRecord(
    Map<String, dynamic> request,
    String dateStr,
    String timeStr,
  ) async {
    if (_doctorId == null) return;

    final patientData = {
      'doctor_id': _doctorId,
      'patient_id': request['user_id'].toString(),
      'doctornote':
          'Initial consultation scheduled for $dateStr at ${_selectedTime!.format(context)}',
      'ai_generatednote': 'AI analysis pending after consultation',
    };

    try {
      // Try to find existing patient record
      final existingPatient = await _supabase
          .from('patients')
          .select('id')
          .eq('doctor_id', _doctorId!)
          .eq('patient_id', request['user_id'].toString())
          .maybeSingle();

      if (existingPatient != null) {
        // Update existing record
        await _supabase
            .from('patients')
            .update({
              'doctornote':
                  'Follow-up consultation scheduled for $dateStr at ${_selectedTime!.format(context)}',
              'ai_generatednote': 'AI analysis pending after consultation',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('doctor_id', _doctorId!)
            .eq('patient_id', request['user_id'].toString());
      } else {
        // Insert new record
        try {
          await _supabase.from('patients').insert(patientData);
        } catch (insertError) {
          // Try uppercase table name if lowercase fails
          await _supabase.from('Patients').insert(patientData);
        }
      }
    } catch (patientError) {
      debugPrint('Error handling patient record: $patientError');
    }
  }

  Future<void> _removeFromCallRequests(Map<String, dynamic> request) async {
    bool requestRemoved = false;

    try {
      // Try to delete the request
      final deleteResult = await _supabase
          .from('call_requests')
          .delete()
          .eq('id', request['id'])
          .select();

      if (deleteResult.isNotEmpty) {
        requestRemoved = true;
      }
    } catch (deleteError) {
      debugPrint('Delete failed: $deleteError');
    }

    // If delete didn't work, mark as accepted
    if (!requestRemoved) {
      try {
        await _supabase
            .from('call_requests')
            .update({'status': 'accepted'})
            .eq('id', request['id']);
        requestRemoved = true;
      } catch (updateError) {
        debugPrint('Status update failed: $updateError');
      }
    }

    // If neither worked, remove from local list manually
    if (!requestRemoved) {
      setState(() {
        _pendingRequests.removeWhere((req) => req['id'] == request['id']);
      });
    }
  }

  String _generateRoomName(String userName) {
    final sanitizedName = userName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .substring(0, userName.length < 10 ? userName.length : 10);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$sanitizedName-$timestamp';
  }

  bool _isMeetingTimeReady(String date, String time) {
    try {
      final now = DateTime.now();
      final appointmentDateTime = DateTime.parse('$date $time');

      final difference = appointmentDateTime.difference(now).inMinutes;
      return difference.abs() <= 10;
    } catch (e) {
      debugPrint('Error parsing meeting time: $e');
      return false;
    }
  }

  bool _isAppointmentExpired(String date, String time) {
    try {
      final now = DateTime.now();
      final appointmentDateTime = DateTime.parse('$date $time');

      return now.isAfter(appointmentDateTime.add(const Duration(minutes: 50)));
    } catch (e) {
      debugPrint('Error parsing appointment expiry: $e');
      return true;
    }
  }

  List<dynamic> get _nonExpiredAppointments {
    return _acceptedAppointments.where((appointment) {
      return !_isAppointmentExpired(appointment['date'], appointment['time']);
    }).toList();
  }

  void _startJitsiMeeting(String patientName, String meetingRoom) {
    try {
      final jitsiMeet = JitsiMeet();

      var listener = JitsiMeetEventListener(
        conferenceJoined: (url) {
          debugPrint("Conference joined: $url");
        },
        conferenceTerminated: (url, error) {
          debugPrint("Conference terminated: $url, error: $error");
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
        conferenceWillJoin: (url) {
          debugPrint("Conference will join: $url");
        },
        participantJoined: (email, name, role, participantId) {
          debugPrint("Participant joined: $name ($email)");
        },
        participantLeft: (participantId) {
          debugPrint("Participant left: $participantId");
        },
        audioMutedChanged: (muted) {
          debugPrint("Audio muted: $muted");
        },
        videoMutedChanged: (muted) {
          debugPrint("Video muted: $muted");
        },
        readyToClose: () {
          debugPrint("Ready to close");
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      );

      var options = JitsiMeetConferenceOptions(
        room: meetingRoom,
        serverURL: "https://meet.jit.si",
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": false,
          "subject": "Consultation with $patientName",
          "prejoinPageEnabled": false,
          "disableModeratorIndicator": false,
        },
        featureFlags: {
          "unsaferoomwarning.enabled": false,
          "pip.enabled": true,
          "invite.enabled": true,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: "Doctor",
          email: _supabase.auth.currentUser?.email ?? "doctor@example.com",
        ),
      );

      jitsiMeet.join(options, listener);
    } catch (e) {
      debugPrint('Error starting Jitsi meeting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start meeting: $e'))
        );
      }
    }
  }

  // Make this method public so it can be called from NavManager
  void refreshData() {
    _initUser();
  }

  @override
  Widget build(BuildContext context) {
    final nonExpiredAppointments = _nonExpiredAppointments;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Doctor Dashboard"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Availability Switch
          Row(
            children: [
              const Text(
                'Available',
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
              Switch(
                value: _isAvailable,
                onChanged: (bool value) => _toggleAvailability(),
                activeColor: Colors.white,
                activeTrackColor: Colors.green,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refreshData,
            tooltip: 'Refresh data',
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your dashboard...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Welcome to your medical practice management system",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Status summary
                  Card(
                    color: Colors.teal[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, color: Colors.teal[600]),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appointment Overview',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[800],
                                ),
                              ),
                              Text(
                                '${nonExpiredAppointments.length} scheduled • ${_pendingRequests.length} pending',
                                style: TextStyle(color: Colors.teal[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Accepted Appointments Section
                  const Text(
                    "Today's Appointments",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  if (nonExpiredAppointments.isEmpty)
                    _buildEmptyState(
                      Icons.calendar_today,
                      'No upcoming appointments',
                      'New appointments will appear here once scheduled',
                    )
                  else
                    ...nonExpiredAppointments.map((appointment) {
                      final isReady = _isMeetingTimeReady(
                        appointment['date'],
                        appointment['time'],
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isReady ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isReady ? Icons.video_call : Icons.schedule,
                              color: isReady ? Colors.green : Colors.blue,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            appointment['user_name'] ?? 'Unknown Patient',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('📅 Date: ${appointment['date']}'),
                              Text('🕐 Time: ${appointment['time']}'),
                              if (isReady)
                                const Text(
                                  '🎥 Meeting ready to start',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: isReady
                                ? () => _startJitsiMeeting(
                                    appointment['user_name'] ?? 'Patient',
                                    appointment['meeting_room'] ??
                                        _generateRoomName(
                                          appointment['user_name'] ?? 'default',
                                        ),
                                  )
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isReady ? Colors.green : Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(isReady ? 'Join' : 'Waiting'),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Pending Requests Section
                  const Text(
                    "Pending Requests",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  if (_pendingRequests.isEmpty)
                    _buildEmptyState(
                      Icons.access_time,
                      'No pending requests',
                      'New consultation requests will appear here',
                    )
                  else
                    ..._pendingRequests.map(
                      (request) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_add,
                              color: Colors.orange,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            request['user_name'] ??
                                request['username'] ??
                                'Unknown Patient',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Requested: ${DateTime.parse(request['created_at']).toLocal()}',
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _showScheduleDialog(request),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Schedule'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.infinity, // Takes full width
        height: 140, // Fixed consistent height
        padding: const EdgeInsets.all(20), // Consistent padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 36, // Consistent icon size
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12), // Consistent spacing
            Text(
              title,
              style: TextStyle(
                fontSize: 16, // Consistent font size
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6), // Consistent spacing
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13, // Consistent font size
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}