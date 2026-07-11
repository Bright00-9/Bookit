enum TipAudience { customer, worker, all }

class AppTip {
  final String title;
  final String body;
  final String emoji;
  final TipAudience audience;

  const AppTip({
    required this.title,
    required this.body,
    required this.emoji,
    this.audience = TipAudience.all,
  });
}

const List<AppTip> appTips = [

  // ── CUSTOMER TIPS ──----
  AppTip(
    emoji: 'Location',
    title: 'Set Your Job Radius',
    body: 'Go to Settings and set how far workers should be notified when you post a job. Smaller radius = faster local response.',
    audience: TipAudience.customer,
  ),
  AppTip(
    emoji: 'Details',
    title: 'Be Detailed in Job Posts',
    body: 'Add photos, a clear description, and a budget to attract better quality applications.',
    audience: TipAudience.customer,
  ),
  AppTip(
    emoji: 'Rating',
    title: 'Rate Your Workers',
    body: 'After a job is done, leave a review. It helps other customers and rewards great workers.',
    audience: TipAudience.customer,
  ),
  AppTip(
    emoji: 'Chat',
    title: 'Chat Before You Hire',
    body: 'Use the in-app chat to discuss job details with a worker before accepting their bid.',
    audience: TipAudience.customer,
  ),
  AppTip(
    emoji: 'Timing',
    title: 'Post Jobs Early',
    body: 'Posting a job earlier in the day increases your chances of getting same-day applications.',
    audience: TipAudience.customer,
  ),
  AppTip(
    emoji: 'Photos',
    title: 'Add Photos to Your Job Post',
    body: 'A photo of the problem helps workers understand the job before they apply, leading to more accurate bids.',
    audience: TipAudience.customer,
  ),
  AppTip(
    emoji: 'Repeat',
    title: 'Rehire Great Workers',
    body: 'Found a worker you loved? You can view your job history and hire them again directly from their profile.',
    audience: TipAudience.customer,
  ),

  // ── WORKER TIPS ──
  AppTip(
    emoji: 'Notifications',
    title: 'Stay Notified',
    body: 'Make sure notifications are enabled so you never miss a job post near you.',
    audience: TipAudience.worker,
  ),
  AppTip(
    emoji: 'Resume',
    title: 'Upload Your Resume',
    body: 'Add your resume to your profile so customers can see your skills and experience before hiring.',
    audience: TipAudience.worker,
  ),
  AppTip(
    emoji: 'Insight',
    title: 'Bid Competitively',
    body: 'When applying for a job, include a clear message explaining why you are the right person for it.',
    audience: TipAudience.worker,
  ),
  AppTip(
    emoji: 'Profile',
    title: 'Complete Your Profile',
    body: 'Profiles with a photo and bio get hired faster. Take a moment to fill in your details.',
    audience: TipAudience.worker,
  ),
  AppTip(
    emoji: 'Location',
    title: 'Keep Your Location Updated',
    body: 'Your location determines which job posts you are notified about. Keep it accurate to get relevant jobs.',
    audience: TipAudience.worker,
  ),
  AppTip(
    emoji: 'Verified',
    title: 'Get Verified',
    body: 'Verified workers get more trust from customers. Go to your profile to submit your ID and get verified.',
    audience: TipAudience.worker,
  ),
  AppTip(
    emoji: 'Speed',
    title: 'Respond Quickly',
    body: 'Workers who respond to job posts within the first hour are more likely to get hired.',
    audience: TipAudience.worker,
  ),
  AppTip(
    emoji: 'Photos',
    title: 'Take Before & After Photos',
    body: 'Document your work with photos. It builds trust and helps resolve any disputes.',
    audience: TipAudience.worker,
  ),

  // ── GENERAL TIPS ──
  AppTip(
    emoji: 'Security',
    title: 'Keep Your Account Secure',
    body: 'Use a strong password and never share your login details with anyone.',
    audience: TipAudience.all,
  ),
  AppTip(
    emoji: 'Update',
    title: 'Update the App',
    body: 'Always keep the app updated to enjoy the latest features and bug fixes.',
    audience: TipAudience.all,
  ),
  AppTip(
    emoji: 'Respect',
    title: 'Be Respectful',
    body: 'Treat everyone on the platform with respect. Good communication leads to better outcomes for everyone.',
    audience: TipAudience.all,
  ),
  AppTip(
    emoji: 'Safety',
    title: 'Stay Safe',
    body: 'Never share personal financial information through chat. All payments go through the app.',
    audience: TipAudience.all,
  ),
  AppTip(
    emoji: 'Chat',
    title: 'Use In-App Chat',
    body: 'Always communicate through the app chat. It keeps your conversations safe and on record.',
    audience: TipAudience.all,
  ),

  // ── ADD YOUR OWN TIPS BELOW ──
  // AppTip(
  //   emoji: '🛠️',
  //   title: 'Your Tip Title',
  //   body: 'Your tip description here.',
  //   audience: TipAudience.customer, // or worker, or all
  // ),
];