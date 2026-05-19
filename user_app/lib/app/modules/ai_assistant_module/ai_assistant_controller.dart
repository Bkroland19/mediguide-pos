import 'package:get/get.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/backend_service.dart';
import '../../data/services/ai_context_service.dart';
import '../../data/models/ai_usage_log.dart';
import '../../data/models/ai_context.dart';
import '../../data/models/backend_record.dart';
import '../../utils/common.dart';

class AiAssistantController extends GetxController {
  static const Duration _chatRequestTimeout = Duration(minutes: 1);

  // Chat controller for managing messages
  late final ChatMessagesController chatController;

  // Observable states
  final RxBool isLoading = false.obs;
  final RxBool isTyping = false.obs;
  final RxList<String> conversationHistory = <String>[].obs;
  final RxString sessionId = ''.obs;

  // Chat users
  late final ChatUser currentUser;
  late final ChatUser aiUser;

  // Context support
  final Rxn<AiContext> currentContext = Rxn<AiContext>();
  final RxString contextualWelcomeMessage = ''.obs;
  final RxList<String> contextualExampleQuestions = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadContextFromArguments();
    _initializeChatComponents();
  }

  @override
  void onClose() {
    chatController.dispose();
    super.onClose();
  }

  /// Load context from navigation arguments
  void _loadContextFromArguments() {
    try {
      final arguments = Get.arguments as Map<String, dynamic>?;
      if (arguments != null && arguments.containsKey('aiContext')) {
        final contextJson = arguments['aiContext'] as Map<String, dynamic>;
        currentContext.value = AiContext.fromJson(contextJson);
        _generateContextualContent();
      }
    } catch (e) {
      // Silently fail if no context or invalid context
      currentContext.value = null;
    }
  }

  /// Generate contextual welcome message and example questions
  void _generateContextualContent() {
    if (currentContext.value != null) {
      try {
        // Generate contextual welcome message
        contextualWelcomeMessage.value = AiContextService.to
            .generateWelcomeMessage(currentContext.value!);

        // Generate contextual example questions
        contextualExampleQuestions.assignAll(
          AiContextService.to.generateExampleQuestions(currentContext.value!),
        );
      } catch (e) {
        // Fall back to default content if service fails
        contextualWelcomeMessage.value = '';
        contextualExampleQuestions.clear();
      }
    }
  }

  /// Initialize chat components following project patterns
  void _initializeChatComponents() {
    // Initialize chat controller
    chatController = ChatMessagesController();

    // Set up current user from AuthService
    final user = AuthService.to.currentUser.value;
    currentUser = ChatUser(
      id: user?.id ?? 'user',
      firstName: user?.name ?? 'You',
    );

    // Set up AI user
    aiUser = ChatUser(id: 'ai_assistant', firstName: 'MediGuide AI');

    // Add welcome message (context-aware if available)
    _addWelcomeMessage();
  }

  /// Add welcome message from AI
  void _addWelcomeMessage() {
    // final welcomeMessage = ChatMessage(
    //   text: '',
    //   user: aiUser,
    //   createdAt: DateTime.now(),
    // );

    // chatController.addMessage(welcomeMessage);
  }

  /// Handle sending messages through the backend AI chat API
  Future<void> handleSendMessage(ChatMessage message) async {
    if (!BackendService.to.isAuthenticated ||
        AuthService.to.currentUser.value == null) {
      final description =
          'Your session expired. Please sign in again to continue using the guideline assistant.';
      Common.quickToast(title: 'Session expired', description: description);
      await _handleErrorResponse(description);
      return;
    }

    try {
      isLoading.value = true;
      isTyping.value = true;

      // Add user message to chat and history
      chatController.addMessage(message);
      conversationHistory.add(message.text);

      // Get AI response
      await _handleAiResponse(message.text);
    } catch (e) {
      final description = Common.parseApiError(e);
      Common.quickToast(title: 'Error', description: description);

      if (e is ClientException) {
        await _handleErrorResponse(description);
      } else {
        await _handleFallbackResponse(message.text);
      }
    } finally {
      isLoading.value = false;
      isTyping.value = false;
    }
  }

  /// Handle AI response
  Future<void> _handleAiResponse(String userMessage) async {
    final response = await BackendService.to.postCustomEndpoint(
      path: '/api/v2/chat/ask',
      body: {
        'question': userMessage.trim(),
        if (sessionId.value.isNotEmpty) 'session_id': sessionId.value,
      },
      timeout: _chatRequestTimeout,
    );
    final data = _extractResponseData(response);
    final answer = data['answer']?.toString().trim() ?? '';
    if (answer.isEmpty) {
      throw Exception('Empty response from AI service');
    }
    sessionId.value = data['session_id']?.toString() ?? sessionId.value;
    final aiResponse = _mergeCitationsIntoAnswer(
      answer,
      data['citations'] as List?,
    );

    // Create AI message
    final aiMessage = ChatMessage(
      text: aiResponse,
      user: aiUser,
      createdAt: DateTime.now(),
    );

    // Add to chat and conversation history
    chatController.addMessage(aiMessage);
    conversationHistory.add(aiResponse);

    // Track usage analytics
    _trackUsage(userMessage, aiResponse);
  }

  Map<String, dynamic> _extractResponseData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return response;
  }

  String _mergeCitationsIntoAnswer(String answer, List<dynamic>? citations) {
    if (citations == null || citations.isEmpty) {
      return answer;
    }

    final lines = <String>[];
    for (final raw in citations) {
      if (raw is! Map) {
        continue;
      }
      final item = Map<String, dynamic>.from(raw);
      final title = item['title']?.toString().trim() ?? '';
      final sourceName = item['source_name']?.toString().trim() ?? '';
      final sourceVersion = item['source_version']?.toString().trim() ?? '';
      final pageStart = item['page_start']?.toString().trim() ?? '';
      final pageEnd = item['page_end']?.toString().trim() ?? '';

      final parts = <String>[
        if (title.isNotEmpty) title,
        if (sourceName.isNotEmpty) sourceName,
        if (sourceVersion.isNotEmpty) 'v$sourceVersion',
        if (pageStart.isNotEmpty && pageEnd.isNotEmpty)
          'pp. $pageStart-$pageEnd'
        else if (pageStart.isNotEmpty)
          'p. $pageStart',
      ];
      if (parts.isNotEmpty) {
        lines.add('- ${parts.join(' • ')}');
      }
    }

    if (lines.isEmpty) {
      return answer;
    }

    return '$answer\n\nSources:\n${lines.join('\n')}';
  }

  /// Handle fallback response when OpenAI is unavailable
  Future<void> _handleFallbackResponse(String userMessage) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final fallbackResponse = _getLocalFallbackResponse(userMessage);

    final aiMessage = ChatMessage(
      text: fallbackResponse,
      user: aiUser,
      createdAt: DateTime.now(),
    );

    chatController.addMessage(aiMessage);
    conversationHistory.add(fallbackResponse);

    // Track usage analytics
    _trackUsage(userMessage, fallbackResponse);
  }

  Future<void> _handleErrorResponse(String description) async {
    final message = _buildBackendErrorMessage(description);
    final aiMessage = ChatMessage(
      text: message,
      user: aiUser,
      createdAt: DateTime.now(),
    );

    chatController.addMessage(aiMessage);
    conversationHistory.add(message);
  }

  String _buildBackendErrorMessage(String description) {
    final clean = description.trim();
    if (clean.isEmpty) {
      return 'The guideline assistant could not complete your request right now. Please try again.';
    }

    final lower = clean.toLowerCase();
    if (lower.contains('invalid token') ||
        lower.contains('unauthorized') ||
        lower.contains('authentication required') ||
        lower.contains('session expired')) {
      return 'Your session expired. Please sign in again to continue using the guideline assistant.';
    }

    if (lower.contains('timed out')) {
      return 'The guideline assistant is taking too long to respond. Please wait a moment and try again.';
    }

    if (lower.contains('forbidden') || lower.contains('permission')) {
      return 'Your account is not allowed to use the guideline assistant. Please contact an administrator.';
    }

    return 'The guideline assistant request failed:\n\n$clean';
  }

  /// Get local fallback response when all else fails
  String _getLocalFallbackResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    if (lowerMessage.contains('drug') || lowerMessage.contains('medicine')) {
      return '💊 **Drug Information**\n\nI can help you with drug information. You can browse our comprehensive drug database in the Drug Index section, or ask me specific questions about medications, dosages, or interactions.\n\n**Disclaimer**: Always verify drug information with qualified healthcare providers.';
    } else if (lowerMessage.contains('guideline') ||
        lowerMessage.contains('protocol')) {
      return '📋 **Clinical Guidelines**\n\nFor clinical guidelines and protocols, you can access our Guidelines section which contains evidence-based treatment protocols. I can also help explain specific guidelines or recommend appropriate ones based on your clinical scenario.\n\n**Note**: Guidelines should be used in conjunction with clinical judgment.';
    } else if (lowerMessage.contains('calculator') ||
        lowerMessage.contains('tool')) {
      return '🧮 **Medical Tools**\n\nOur Tools section includes medical calculators, decision tools, and checklists. These can help with clinical calculations, risk assessments, and decision-making support. What type of calculation do you need help with?\n\n**Available Tools**: BMI, dosage calculators, risk assessments, and more.';
    } else if (lowerMessage.contains('emergency') ||
        lowerMessage.contains('urgent')) {
      return '🚨 **MEDICAL EMERGENCY**\n\nIf this is a life-threatening emergency:\n• Call emergency services immediately\n• Seek immediate medical attention\n• Contact the nearest healthcare facility\n\n**MediGuide Resources**:\n• Guidelines for emergency protocols\n• Drug Index for emergency medications\n• Consultants for expert advice\n\n**Disclaimer**: This is not a substitute for emergency medical care.';
    } else {
      return '🤖 **MediGuide AI Assistant**\n\nThank you for your question. I can guide you to the relevant sections of MediGuide:\n\n• **Drug Index**: Comprehensive medication information\n• **Guidelines**: Clinical treatment protocols  \n• **Tools**: Medical calculators and decision aids\n• **Consultants**: Connect with medical experts\n\nCould you please be more specific about what you\'d like to know?\n\n**Disclaimer**: Always consult with qualified healthcare providers for medical decisions.';
    }
  }

  /// Track AI usage for basic counting
  Future<void> _trackUsage(String query, String response) async {
    try {
      final currentUser = AuthService.to.currentUser.value;
      if (currentUser == null) return;

      final usageData = AiUsageLog.forCreate(userId: currentUser.id);

      // Save to backend asynchronously (don't block UI)
      BackendService.to.createRecord(
        collectionName: AiUsageLog.collection,
        data: usageData,
      );
    } catch (e) {
      // Silently fail - usage tracking shouldn't break the app
    }
  }

  /// Get contextual example questions based on user's recent activity
  Future<List<String>> getContextualQuestions() async {
    return defaultExampleQuestions;
  }

  /// Default example questions when no context is available
  List<String> get defaultExampleQuestions => [
    'What are the side effects of paracetamol?',
    'Show me hypertension treatment guidelines',
    'How do I calculate BMI?',
    'What are the symptoms of malaria?',
    'Emergency protocols for chest pain',
  ];

  /// Get example questions to show in UI (with contextual intelligence)
  List<String> get exampleQuestions => contextualExampleQuestions.isNotEmpty
      ? contextualExampleQuestions.toList()
      : defaultExampleQuestions;

  /// Load contextual questions (call this after initialization)
  Future<void> loadContextualQuestions() async {
    await getContextualQuestions();
    // Update example questions if needed
    // Note: You might want to make exampleQuestions reactive (RxList) to update UI
  }
}
