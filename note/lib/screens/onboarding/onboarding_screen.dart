import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _currentPage = 0;
  final int _numPages = 3;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Chào mừng đến với AppNote',
      'description':
          'Tạo, quản lý và tổ chức tất cả ghi chú của bạn trong một nơi duy nhất.',
      'lottie': 'assets/animations/notes_animation.json',
      'backgroundColor': const Color(0xFFE3F2FD),
      'textColor': const Color(0xFF1565C0),
    },
    {
      'title': 'Truy cập mọi lúc mọi nơi',
      'description': 'Ghi chú của bạn được đồng bộ hóa trên tất cả các thiết bị.',
      'lottie': 'assets/animations/sync_animation.json',
      'backgroundColor': const Color(0xFFE8F5E9),
      'textColor': const Color(0xFF2E7D32),
    },
    {
      'title': 'Luôn ngăn nắp có tổ chức',
      'description':
          'Đặt lời nhắc, ghim ghi chú quan trọng và tùy chỉnh theo ý thích của bạn.',
      'lottie': 'assets/animations/organize_animation.json',
      'backgroundColor': const Color(0xFFFFF3E0),
      'textColor': const Color(0xFFE65100),
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _nextPage() {
    if (_currentPage == _numPages - 1) {
      _completeOnboarding();
    } else {
      _animationController.reset();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      _animationController.forward();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _animationController.reset();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient container
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _onboardingData[_currentPage]['backgroundColor'],
                  _onboardingData[_currentPage]['backgroundColor'].withOpacity(0.7),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button (shown only if not on first page)
                      _currentPage > 0
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back_ios),
                              onPressed: _previousPage,
                              color: _onboardingData[_currentPage]['textColor'],
                            )
                          : const SizedBox(width: 48),
                      
                      // Skip button
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          'Bỏ qua',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _onboardingData[_currentPage]['textColor'],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                        _animationController.reset();
                        _animationController.forward();
                      });
                    },
                    itemCount: _numPages,
                    itemBuilder: (context, index) {
                      return _buildOnboardingPage(
                        _onboardingData[index]['title']!,
                        _onboardingData[index]['description']!,
                        _onboardingData[index]['lottie']!,
                        _onboardingData[index]['textColor']!,
                        size,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dots indicator
                      Row(
                        children: List.generate(
                          _numPages,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 24 : 10,
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: _currentPage == index
                                  ? _onboardingData[_currentPage]['textColor']
                                  : _onboardingData[_currentPage]['textColor'].withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                      // Next/Done button
                      GestureDetector(
                        onTap: _nextPage,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _onboardingData[_currentPage]['textColor'],
                            boxShadow: [
                              BoxShadow(
                                color: _onboardingData[_currentPage]['textColor'].withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            _currentPage == _numPages - 1
                                ? Icons.check
                                : Icons.arrow_forward,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage(
    String title,
    String description,
    String animationPath,
    Color textColor,
    Size size,
  ) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                alignment: Alignment.center,
                child: Lottie.asset(
                  animationPath,
                  width: size.width * 0.8,
                  height: size.width * 0.8,
                  fit: BoxFit.contain,
                  repeat: true,
                  // Fallback cho trường hợp file lottie chưa có
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.note_alt,
                    size: 150,
                    color: textColor,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      height: 1.5,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
