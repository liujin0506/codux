import 'package:codux_flutter/models/remote_models.dart';
import 'package:codux_flutter/services/remote_project_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const controller = RemoteProjectController();
  const project = ProjectInfo(id: 'project-1', name: 'Project', path: '/repo');

  test('builds add project envelope with path-derived name', () {
    final plan = controller.savePlan(
      mode: ProjectFormMode.add,
      path: '/Volumes/Web/codux',
      name: '',
    );

    expect(plan.valid, isTrue);
    expect(plan.name, 'codux');
    expect(plan.envelope!.type, 'project.add');
    expect((plan.envelope!.payload as Map)['name'], 'codux');
  });

  test('builds edit project envelope with selected project', () {
    final plan = controller.savePlan(
      mode: ProjectFormMode.edit,
      path: '/repo-next',
      name: 'Repo Next',
      selectedProject: project,
    );

    expect(plan.valid, isTrue);
    expect(plan.envelope!.type, 'project.edit');
    expect((plan.envelope!.payload as Map)['projectId'], 'project-1');
    expect((plan.envelope!.payload as Map)['path'], '/repo-next');
  });

  test('builds project form drafts', () {
    final edit = controller.editDraft(project);
    expect(edit.mode, ProjectFormMode.edit);
    expect(edit.name, 'Project');
    expect(edit.path, '/repo');

    final add = controller.addDraft();
    expect(add.mode, ProjectFormMode.add);
    expect(add.name, isEmpty);
    expect(add.path, isEmpty);
  });

  test('rejects invalid save plans', () {
    expect(
      controller.savePlan(mode: ProjectFormMode.add, path: '', name: '').valid,
      isFalse,
    );
    expect(
      controller
          .savePlan(mode: ProjectFormMode.edit, path: '/repo', name: 'Repo')
          .valid,
      isFalse,
    );
  });

  test('scopes AI session envelopes to the selected worktree path', () {
    const worktree = RemoteWorktreeInfo(
      id: 'worktree-1',
      projectId: 'project-1',
      name: 'feat',
      branch: 'feat',
      path: '/repo/.codux/worktrees/feat',
      status: 'clean',
      isDefault: false,
      exists: true,
      changes: 0,
      incoming: 0,
      outgoing: 0,
      additions: 0,
      deletions: 0,
    );

    final list = controller.aiSessionListEnvelope(project, worktree: worktree);
    expect(list.type, 'ai.session');
    expect((list.payload as Map)['op'], 'list');
    expect((list.payload as Map)['projectId'], 'project-1');
    expect((list.payload as Map)['projectName'], 'feat');
    expect((list.payload as Map)['projectPath'], '/repo/.codux/worktrees/feat');
    expect((list.payload as Map)['worktreeId'], 'worktree-1');
    expect((list.payload as Map)['refresh'], isTrue);

    final rename = controller.aiSessionRenameEnvelope(
      project,
      'sess-1',
      'Renamed',
      worktree: worktree,
    );
    expect((rename.payload as Map)['op'], 'indexedRename');
    final remove = controller.aiSessionRemoveEnvelope(
      project,
      'sess-1',
      worktree: worktree,
    );
    expect((remove.payload as Map)['op'], 'indexedRemove');

    final restore = controller.aiSessionRestoreEnvelope(
      project,
      'sess-1',
      worktree: worktree,
    );
    expect(
      (restore.payload as Map)['projectPath'],
      '/repo/.codux/worktrees/feat',
    );
    expect((restore.payload as Map)['worktreeId'], 'worktree-1');
  });

  test('AI session envelopes fall back to the project path', () {
    final list = controller.aiSessionListEnvelope(project);
    expect((list.payload as Map)['projectPath'], '/repo');
    expect((list.payload as Map).containsKey('worktreeId'), isFalse);
    expect((list.payload as Map)['projectName'], 'Project');
    expect((list.payload as Map)['refresh'], isTrue);
  });

  test('builds project utility envelopes', () {
    expect(controller.removeEnvelope(project).type, 'project.remove');
    expect(controller.aiStatsEnvelope(project).type, 'ai.stats');
    expect(
      (controller.aiStatsEnvelope(project, refresh: true).payload
          as Map)['refresh'],
      isTrue,
    );
    expect(
      (controller.aiStatsEnvelope(project, worktreeId: 'worktree-1').payload
          as Map)['worktreeId'],
      'worktree-1',
    );
    expect(controller.gitStatusEnvelope(project).type, 'git.status');
    expect(
      (controller.gitStatusEnvelope(project).payload as Map)['projectPath'],
      '/repo',
    );
  });

  test('builds file picker list envelope', () {
    expect(controller.filePickerListEnvelope(null).payload, isEmpty);
    expect(
      (controller.filePickerListEnvelope('/repo').payload as Map)['path'],
      '/repo',
    );
  });

  test('uses entry name or path tail for folder display name', () {
    expect(
      controller.folderDisplayName(
        const RemoteFileEntry(
          name: 'repo',
          path: '/Volumes/Web/repo',
          isDirectory: true,
        ),
      ),
      'repo',
    );
    expect(
      controller.folderDisplayName(
        const RemoteFileEntry(
          name: '',
          path: r'C:\work\repo',
          isDirectory: true,
        ),
      ),
      'repo',
    );
  });

  test('selects folder path and only fills missing project name', () {
    const entry = RemoteFileEntry(
      name: '',
      path: '/Volumes/Web/repo',
      isDirectory: true,
    );

    final inferred = controller.selectFolder(entry: entry, currentName: '');
    expect(inferred.path, '/Volumes/Web/repo');
    expect(inferred.name, 'repo');

    final existing = controller.selectFolder(
      entry: entry,
      currentName: 'Existing',
    );
    expect(existing.name, 'Existing');
  });
}
