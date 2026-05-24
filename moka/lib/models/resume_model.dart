class ResumeModel {
  final String? fileUrl;
  final String? fullName;
  final String? summary;
  final String? experience;
  final String? education;
  final String? skills;

  ResumeModel({
    this.fileUrl,
    this.fullName,
    this.summary,
    this.experience,
    this.education,
    this.skills,
  });

  Map<String, dynamic> toJson() => {
    'file_url': fileUrl,
    'full_name': fullName,
    'summary': summary,
    'experience': experience,
    'education': education,
    'skills': skills,
  };

  factory ResumeModel.fromJson(Map<String, dynamic> json) => ResumeModel(
    fileUrl: json['file_url'],
    fullName: json['full_name'],
    summary: json['summary'],
    experience: json['experience'],
    education: json['education'],
    skills: json['skills'],
  );
}