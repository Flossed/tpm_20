# 🏗️ GitHub Project Structure Guide

This document explains the comprehensive project management structure for the ZANDD HSM & Certificate Authority project.

## 📋 Issue Templates

### 🏗️ Epic Template (`epic.yml`)
**Purpose**: Large features or initiatives spanning multiple stories
**Usage**: Use for major feature development like "HSM Management Interface"
**Fields**:
- Epic title and description
- Business value and acceptance criteria  
- Priority and component assignment
- Target release and related user stories
- Technical considerations

### 📖 User Story Template (`user-story.yml`)
**Purpose**: Feature requests from user perspective
**Usage**: Individual user-facing features and functionality
**Fields**:
- User story in "As a... I want... So that..." format
- Acceptance criteria with Given/When/Then structure
- Story points estimation (Fibonacci sequence)
- Component and priority assignment
- Definition of done checklist

### ✅ Task Template (`task.yml`)  
**Purpose**: Development tasks or technical work items
**Usage**: Specific implementation tasks, sub-tasks of stories
**Fields**:
- Task type (Development, Testing, Documentation, etc.)
- Effort estimation (XS to XXL)
- Technical approach and dependencies
- Acceptance criteria and testing notes

### 🐛 Bug Report Template (`bug.yml`)
**Purpose**: Report bugs, issues, or unexpected behavior
**Usage**: Any software defects or problems
**Fields**:
- Detailed steps to reproduce
- Severity and frequency ratings
- Environment information
- Error logs and screenshots
- Troubleshooting checklist

### 🚀 Release Template (`release.yml`)
**Purpose**: Plan and track product releases
**Usage**: Major version releases and release planning
**Fields**:
- Release version and type
- Features and epics included
- Release criteria and testing plan
- Deployment and rollback strategies
- Success metrics and communication plan

## 🤖 GitHub Actions Workflows

### 📋 Project Management Automation (`project-management.yml`)

**Triggers**: Issue opened, edited, closed, PR events
**Features**:
- **Auto-labeling**: Assigns component labels based on file paths
- **Epic management**: Creates project boards for new epics
- **Story validation**: Ensures story points are assigned
- **Task assignment**: Auto-assigns based on component expertise
- **Bug triage**: Prioritizes critical bugs automatically
- **Metrics calculation**: Tracks cycle time and velocity

### 🚀 Release Automation (`release-automation.yml`)

**Triggers**: Version tags (v*.*.*) or manual workflow dispatch
**Features**:
- **Version validation**: Ensures semantic versioning compliance
- **Artifact building**: Compiles all project components
- **Security scanning**: Checks for vulnerabilities and secrets
- **Release creation**: Generates GitHub releases with notes
- **Asset uploading**: Attaches binaries and packages
- **Post-release tasks**: Updates milestones and notifies team

## 🏷️ Labeling System

### Component Labels
- `component/hsm-core` - HSM and TPM functionality
- `component/web-services` - API and web services
- `component/ui` - User interface components
- `component/certificate-authority` - CA functionality
- `component/security` - Security-related features
- `component/documentation` - Documentation updates
- `component/infrastructure` - Deployment and DevOps
- `component/testing` - Test code and quality assurance

### Priority Labels
- `priority/high` - Critical issues requiring immediate attention
- `priority/medium` - Important enhancements
- `priority/low` - Nice-to-have improvements

### Type Labels  
- `epic` - Large initiatives spanning multiple stories
- `story` - User-facing features
- `task` - Development work items
- `bug` - Software defects
- `release` - Release planning and tracking

### Status Labels
- `needs-triage` - Requires initial review and assignment
- `in-progress` - Currently being worked on
- `blocked` - Waiting on dependencies
- `needs-review` - Ready for code review
- `needs-testing` - Requires testing before closure

## 📊 Project Boards

### Epic Boards
- Automatically created for each epic
- Columns: Backlog, In Progress, Review, Done
- Contains all stories and tasks for the epic

### Sprint Boards
- Manual creation for sprint planning
- Standard agile workflow columns
- Time-boxed iterations (2-4 weeks)

### Release Boards  
- Track progress toward release milestones
- Show completion status of features
- Risk and dependency visualization

## 🎯 Workflow Examples

### Creating a New Epic
1. Click "New Issue" → Select "🏗️ Epic"
2. Fill out epic template with business value
3. Automation creates dedicated project board
4. Break down into user stories (separate issues)
5. Link stories to epic using "Parent Epic" field

### Story Development Flow
1. Create user story from template
2. Add story points and acceptance criteria
3. Break into development tasks
4. Assign to sprint/milestone
5. Automation tracks progress and metrics

### Bug Reporting Process
1. Use "🐛 Bug Report" template
2. Provide detailed reproduction steps
3. Automation triages based on severity
4. Critical bugs get immediate attention
5. Metrics tracked for resolution time

### Release Planning
1. Create release issue with target version
2. Automation creates milestone
3. Assign epics and stories to release
4. Track completion via project board
5. Automated release when tag is pushed

## 📈 Metrics and Reporting

### Automated Metrics
- **Cycle Time**: Days from creation to closure
- **Velocity**: Story points completed per sprint
- **Bug Resolution**: Time to fix by severity
- **Release Cadence**: Frequency and predictability

### Reports Generated
- Sprint velocity reports
- Burndown charts (via project boards)
- Component health dashboards
- Security and quality metrics

## 🔧 Configuration Files

### `config.yml`
- Disables blank issues
- Provides helpful links (docs, discussions, security)
- Guides users to appropriate channels

### `labeler-config.yml` 
- Defines automatic labeling rules
- Maps file paths to components
- Assigns size labels based on file types

### `PULL_REQUEST_TEMPLATE.md`
- Standard PR review checklist
- Links to related issues
- Security and testing requirements

## 🚀 Getting Started

### For Developers
1. **Create Issues**: Use appropriate templates for work items
2. **Follow Workflows**: Let automation handle routine tasks
3. **Link Work**: Connect PRs to issues with `Closes #123`
4. **Update Status**: Move cards on project boards

### For Project Managers
1. **Plan Epics**: Use epic template for large initiatives  
2. **Create Sprints**: Set up sprint milestones and boards
3. **Track Progress**: Monitor automated metrics and reports
4. **Plan Releases**: Use release template for version planning

### For Stakeholders
1. **View Progress**: Check project boards and milestones
2. **Request Features**: Use story template for new requirements
3. **Report Issues**: Use bug template for problems
4. **Track Releases**: Follow release issues for updates

## 📚 Best Practices

### Issue Management
- Use descriptive, searchable titles
- Add all relevant labels and assignments
- Link related issues and PRs
- Keep issues focused and atomic

### Story Writing
- Follow "As a... I want... So that..." format
- Include testable acceptance criteria
- Estimate story points consistently
- Define clear definition of done

### Task Breakdown
- Create tasks for each story
- Keep tasks under 8 hours each
- Include technical implementation details
- Specify dependencies clearly

### Release Management
- Plan releases around business value
- Include breaking changes and migration notes
- Test thoroughly before release
- Communicate changes to stakeholders

---

This structure provides comprehensive project management capabilities while maintaining simplicity and automation. The system scales from individual tasks to enterprise releases, with built-in quality controls and metrics tracking.

*ZANDD HSM Project Management Structure - August 2025*