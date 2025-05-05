import 'package:eisenvaultappflutter/models/browse_item.dart';

/// Represents an item that can be kept offline
class OfflineItem {
  /// Unique identifier of the item
  final String id;

  /// Name of the item
  final String name;

  /// Type of the item (file, folder, etc.)
  final String type;

  /// Parent folder ID
  final String? parentId;

  /// File path of the item
  final String? filePath;

  /// Description of the item
  final String? description;

  /// Modified date of the item
  final DateTime? modifiedDate;

  /// Modified by of the item
  final String? modifiedBy;

  /// Constructor
  const OfflineItem({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.filePath,
    this.description,
    this.modifiedDate,
    this.modifiedBy,
  });

  /// Create an OfflineItem from a BrowseItem
  factory OfflineItem.fromBrowseItem(BrowseItem item, {String? parentId}) {
    return OfflineItem(
      id: item.id,
      name: item.name,
      type: item.type,
      parentId: parentId,
      description: item.description,
      modifiedDate: item.modifiedDate != null ? DateTime.parse(item.modifiedDate!) : null,
      modifiedBy: item.modifiedBy,
    );
  }

  /// Create a copy of this OfflineItem with some fields replaced
  OfflineItem copyWith({
    String? id,
    String? name,
    String? type,
    String? parentId,
    String? filePath,
    String? description,
    DateTime? modifiedDate,
    String? modifiedBy,
  }) {
    return OfflineItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      filePath: filePath ?? this.filePath,
      description: description ?? this.description,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      modifiedBy: modifiedBy ?? this.modifiedBy,
    );
  }

  /// Whether the item is a folder
  bool get isFolder => type == 'folder';

  /// Whether the item is a file
  bool get isFile => type == 'file';

  /// Whether the item is a department
  bool get isDepartment => type == 'department';

  /// Whether the item is a workspace
  bool get isWorkspace => type == 'workspace';

  /// Whether the item is a site
  bool get isSite => type == 'site';

  /// Whether the item is a space
  bool get isSpace => type == 'space';

  /// Whether the item is a group
  bool get isGroup => type == 'group';

  /// Whether the item is a user
  bool get isUser => type == 'user';

  /// Whether the item is a person
  bool get isPerson => type == 'person';

  /// Whether the item is a category
  bool get isCategory => type == 'category';

  /// Whether the item is a tag
  bool get isTag => type == 'tag';

  /// Whether the item is a link
  bool get isLink => type == 'link';

  /// Whether the item is a shortcut
  bool get isShortcut => type == 'shortcut';

  /// Whether the item is a search
  bool get isSearch => type == 'search';

  /// Whether the item is a saved search
  bool get isSavedSearch => type == 'saved_search';

  /// Whether the item is a favorite
  bool get isFavorite => type == 'favorite';

  /// Whether the item is a recent
  bool get isRecent => type == 'recent';

  /// Whether the item is a shared
  bool get isShared => type == 'shared';

  /// Whether the item is a trash
  bool get isTrash => type == 'trash';

  /// Whether the item is a recycle bin
  bool get isRecycleBin => type == 'recycle_bin';

  /// Whether the item is a version
  bool get isVersion => type == 'version';

  /// Whether the item is a comment
  bool get isComment => type == 'comment';

  /// Whether the item is a task
  bool get isTask => type == 'task';

  /// Whether the item is a workflow
  bool get isWorkflow => type == 'workflow';

  /// Whether the item is a process
  bool get isProcess => type == 'process';

  /// Whether the item is a form
  bool get isForm => type == 'form';

  /// Whether the item is a template
  bool get isTemplate => type == 'template';

  /// Whether the item is a report
  bool get isReport => type == 'report';

  /// Whether the item is a dashboard
  bool get isDashboard => type == 'dashboard';

  /// Whether the item is a chart
  bool get isChart => type == 'chart';

  /// Whether the item is a graph
  bool get isGraph => type == 'graph';

  /// Whether the item is a table
  bool get isTable => type == 'table';

  /// Whether the item is a list
  bool get isList => type == 'list';

  /// Whether the item is a grid
  bool get isGrid => type == 'grid';

  /// Whether the item is a calendar
  bool get isCalendar => type == 'calendar';

  /// Whether the item is a timeline
  bool get isTimeline => type == 'timeline';

  /// Whether the item is a map
  bool get isMap => type == 'map';

  /// Whether the item is a location
  bool get isLocation => type == 'location';

  /// Whether the item is a place
  bool get isPlace => type == 'place';

  /// Whether the item is a address
  bool get isAddress => type == 'address';

  /// Whether the item is a contact
  bool get isContact => type == 'contact';

  /// Whether the item is a person
  bool get isPersonContact => type == 'person_contact';

  /// Whether the item is a organization
  bool get isOrganization => type == 'organization';

  /// Whether the item is a company
  bool get isCompany => type == 'company';

  /// Whether the item is a business
  bool get isBusiness => type == 'business';

  /// Whether the item is a enterprise
  bool get isEnterprise => type == 'enterprise';

  /// Whether the item is a corporation
  bool get isCorporation => type == 'corporation';

  /// Whether the item is a institution
  bool get isInstitution => type == 'institution';

  /// Whether the item is a agency
  bool get isAgency => type == 'agency';

  /// Whether the item is a department
  bool get isDepartmentOrg => type == 'department_org';

  /// Whether the item is a division
  bool get isDivision => type == 'division';

  /// Whether the item is a unit
  bool get isUnit => type == 'unit';

  /// Whether the item is a team
  bool get isTeam => type == 'team';

  /// Whether the item is a group
  bool get isGroupOrg => type == 'group_org';

  /// Whether the item is a project
  bool get isProject => type == 'project';

  /// Whether the item is a program
  bool get isProgram => type == 'program';

  /// Whether the item is a initiative
  bool get isInitiative => type == 'initiative';

  /// Whether the item is a campaign
  bool get isCampaign => type == 'campaign';

  /// Whether the item is a event
  bool get isEvent => type == 'event';

  /// Whether the item is a meeting
  bool get isMeeting => type == 'meeting';

  /// Whether the item is a conference
  bool get isConference => type == 'conference';

  /// Whether the item is a workshop
  bool get isWorkshop => type == 'workshop';

  /// Whether the item is a seminar
  bool get isSeminar => type == 'seminar';

  /// Whether the item is a webinar
  bool get isWebinar => type == 'webinar';

  /// Whether the item is a training
  bool get isTraining => type == 'training';

  /// Whether the item is a course
  bool get isCourse => type == 'course';

  /// Whether the item is a class
  bool get isClass => type == 'class';

  /// Whether the item is a lesson
  bool get isLesson => type == 'lesson';

  /// Whether the item is a module
  bool get isModule => type == 'module';

  /// Whether the item is a unit
  bool get isUnitEdu => type == 'unit_edu';

  /// Whether the item is a chapter
  bool get isChapter => type == 'chapter';

  /// Whether the item is a section
  bool get isSection => type == 'section';

  /// Whether the item is a part
  bool get isPart => type == 'part';

  /// Whether the item is a volume
  bool get isVolume => type == 'volume';

  /// Whether the item is a book
  bool get isBook => type == 'book';

  /// Whether the item is a document
  bool get isDocument => type == 'document';

  /// Whether the item is a file
  bool get isFileDoc => type == 'file_doc';

  /// Whether the item is a folder
  bool get isFolderDoc => type == 'folder_doc';

  /// Whether the item is a workspace
  bool get isWorkspaceDoc => type == 'workspace_doc';

  /// Whether the item is a site
  bool get isSiteDoc => type == 'site_doc';

  /// Whether the item is a space
  bool get isSpaceDoc => type == 'space_doc';

  /// Whether the item is a group
  bool get isGroupDoc => type == 'group_doc';

  /// Whether the item is a user
  bool get isUserDoc => type == 'user_doc';

  /// Whether the item is a person
  bool get isPersonDoc => type == 'person_doc';

  /// Whether the item is a category
  bool get isCategoryDoc => type == 'category_doc';

  /// Whether the item is a tag
  bool get isTagDoc => type == 'tag_doc';

  /// Whether the item is a link
  bool get isLinkDoc => type == 'link_doc';

  /// Whether the item is a shortcut
  bool get isShortcutDoc => type == 'shortcut_doc';

  /// Whether the item is a search
  bool get isSearchDoc => type == 'search_doc';

  /// Whether the item is a saved search
  bool get isSavedSearchDoc => type == 'saved_search_doc';

  /// Whether the item is a favorite
  bool get isFavoriteDoc => type == 'favorite_doc';

  /// Whether the item is a recent
  bool get isRecentDoc => type == 'recent_doc';

  /// Whether the item is a shared
  bool get isSharedDoc => type == 'shared_doc';

  /// Whether the item is a trash
  bool get isTrashDoc => type == 'trash_doc';

  /// Whether the item is a recycle bin
  bool get isRecycleBinDoc => type == 'recycle_bin_doc';

  /// Whether the item is a version
  bool get isVersionDoc => type == 'version_doc';

  /// Whether the item is a comment
  bool get isCommentDoc => type == 'comment_doc';

  /// Whether the item is a task
  bool get isTaskDoc => type == 'task_doc';

  /// Whether the item is a workflow
  bool get isWorkflowDoc => type == 'workflow_doc';

  /// Whether the item is a process
  bool get isProcessDoc => type == 'process_doc';

  /// Whether the item is a form
  bool get isFormDoc => type == 'form_doc';

  /// Whether the item is a template
  bool get isTemplateDoc => type == 'template_doc';

  /// Whether the item is a report
  bool get isReportDoc => type == 'report_doc';

  /// Whether the item is a dashboard
  bool get isDashboardDoc => type == 'dashboard_doc';

  /// Whether the item is a chart
  bool get isChartDoc => type == 'chart_doc';

  /// Whether the item is a graph
  bool get isGraphDoc => type == 'graph_doc';

  /// Whether the item is a table
  bool get isTableDoc => type == 'table_doc';

  /// Whether the item is a list
  bool get isListDoc => type == 'list_doc';

  /// Whether the item is a grid
  bool get isGridDoc => type == 'grid_doc';

  /// Whether the item is a calendar
  bool get isCalendarDoc => type == 'calendar_doc';

  /// Whether the item is a timeline
  bool get isTimelineDoc => type == 'timeline_doc';

  /// Whether the item is a map
  bool get isMapDoc => type == 'map_doc';

  /// Whether the item is a location
  bool get isLocationDoc => type == 'location_doc';

  /// Whether the item is a place
  bool get isPlaceDoc => type == 'place_doc';

  /// Whether the item is a address
  bool get isAddressDoc => type == 'address_doc';

  /// Whether the item is a contact
  bool get isContactDoc => type == 'contact_doc';

  /// Whether the item is a person
  bool get isPersonContactDoc => type == 'person_contact_doc';

  /// Whether the item is a organization
  bool get isOrganizationDoc => type == 'organization_doc';

  /// Whether the item is a company
  bool get isCompanyDoc => type == 'company_doc';

  /// Whether the item is a business
  bool get isBusinessDoc => type == 'business_doc';

  /// Whether the item is a enterprise
  bool get isEnterpriseDoc => type == 'enterprise_doc';

  /// Whether the item is a corporation
  bool get isCorporationDoc => type == 'corporation_doc';

  /// Whether the item is a institution
  bool get isInstitutionDoc => type == 'institution_doc';

  /// Whether the item is a agency
  bool get isAgencyDoc => type == 'agency_doc';

  /// Whether the item is a department
  bool get isDepartmentOrgDoc => type == 'department_org_doc';

  /// Whether the item is a division
  bool get isDivisionDoc => type == 'division_doc';

  /// Whether the item is a unit
  bool get isUnitDoc => type == 'unit_doc';

  /// Whether the item is a team
  bool get isTeamDoc => type == 'team_doc';

  /// Whether the item is a group
  bool get isGroupOrgDoc => type == 'group_org_doc';

  /// Whether the item is a project
  bool get isProjectDoc => type == 'project_doc';

  /// Whether the item is a program
  bool get isProgramDoc => type == 'program_doc';

  /// Whether the item is a initiative
  bool get isInitiativeDoc => type == 'initiative_doc';

  /// Whether the item is a campaign
  bool get isCampaignDoc => type == 'campaign_doc';

  /// Whether the item is a event
  bool get isEventDoc => type == 'event_doc';

  /// Whether the item is a meeting
  bool get isMeetingDoc => type == 'meeting_doc';

  /// Whether the item is a conference
  bool get isConferenceDoc => type == 'conference_doc';

  /// Whether the item is a workshop
  bool get isWorkshopDoc => type == 'workshop_doc';

  /// Whether the item is a seminar
  bool get isSeminarDoc => type == 'seminar_doc';

  /// Whether the item is a webinar
  bool get isWebinarDoc => type == 'webinar_doc';

  /// Whether the item is a training
  bool get isTrainingDoc => type == 'training_doc';

  /// Whether the item is a course
  bool get isCourseDoc => type == 'course_doc';

  /// Whether the item is a class
  bool get isClassDoc => type == 'class_doc';

  /// Whether the item is a lesson
  bool get isLessonDoc => type == 'lesson_doc';

  /// Whether the item is a module
  bool get isModuleDoc => type == 'module_doc';

  /// Whether the item is a unit
  bool get isUnitEduDoc => type == 'unit_edu_doc';

  /// Whether the item is a chapter
  bool get isChapterDoc => type == 'chapter_doc';

  /// Whether the item is a section
  bool get isSectionDoc => type == 'section_doc';

  /// Whether the item is a part
  bool get isPartDoc => type == 'part_doc';

  /// Whether the item is a volume
  bool get isVolumeDoc => type == 'volume_doc';

  /// Whether the item is a book
  bool get isBookDoc => type == 'book_doc';

  /// Convert to a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'parentId': parentId,
      'filePath': filePath,
      'description': description,
      'modifiedDate': modifiedDate?.toIso8601String(),
      'modifiedBy': modifiedBy,
    };
  }
} 