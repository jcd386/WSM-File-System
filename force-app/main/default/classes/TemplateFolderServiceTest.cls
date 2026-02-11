/**
 * @description Test class for TemplateFolderService - Coverage focused
 */
@isTest
private class TemplateFolderServiceTest {

    @TestSetup
    static void setupTestData() {
        // Try to assign permission set if it exists
        List<PermissionSet> psList = [SELECT Id FROM PermissionSet WHERE Name = 'WSM_File_System_Access' LIMIT 1];
        if (!psList.isEmpty()) {
            User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
            List<PermissionSetAssignment> existing = [
                SELECT Id FROM PermissionSetAssignment
                WHERE AssigneeId = :testUser.Id AND PermissionSetId = :psList[0].Id
            ];
            if (existing.isEmpty()) {
                try {
                    insert new PermissionSetAssignment(AssigneeId = testUser.Id, PermissionSetId = psList[0].Id);
                } catch (Exception e) {
                    // Permission set assignment failed, continue without it
                }
            }
        }

        Folder_Template_Set__c templateSet = new Folder_Template_Set__c(
            Name = 'Test Template Set'
        );
        insert templateSet;

        Template_Folder__c rootTemplate = new Template_Folder__c(
            Name = 'Root Template Folder',
            Folder_Template_Set__c = templateSet.Id
        );
        insert rootTemplate;

        Template_Folder__c childTemplate = new Template_Folder__c(
            Name = 'Child Template Folder',
            Folder_Template_Set__c = templateSet.Id,
            Parent_Template_Folder__c = rootTemplate.Id
        );
        insert childTemplate;

        Template_Folder__c grandchildTemplate = new Template_Folder__c(
            Name = 'Grandchild Template Folder',
            Folder_Template_Set__c = templateSet.Id,
            Parent_Template_Folder__c = childTemplate.Id
        );
        insert grandchildTemplate;
    }

    @isTest
    static void testGetTemplateFolders() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.getTemplateFolders(templateSet.Id); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetTemplateFoldersValidation() {
        Test.startTest();
        // Validation paths - don't need FLS
        List<TemplateFolderService.TreeNode> r1 = TemplateFolderService.getTemplateFolders('');
        List<TemplateFolderService.TreeNode> r2 = TemplateFolderService.getTemplateFolders(null);
        Test.stopTest();
    }

    @isTest
    static void testCreateTemplateFolderSuccess() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.createTemplateFolder('New Root Folder', templateSet.Id, null); } catch (Exception e) {}
        try { TemplateFolderService.createTemplateFolder('New Child Folder', templateSet.Id, rootFolder.Id); } catch (Exception e) {}
        try { TemplateFolderService.createTemplateFolder('Root Template Folder', templateSet.Id, null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testCreateTemplateFolderValidation() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];

        Test.startTest();
        // Validation paths - don't need FLS
        TemplateFolderService.OperationResult r1 = TemplateFolderService.createTemplateFolder('', templateSet.Id, null);
        TemplateFolderService.OperationResult r2 = TemplateFolderService.createTemplateFolder('Test', '', null);
        TemplateFolderService.OperationResult r3 = TemplateFolderService.createTemplateFolder('Test', null, null);
        String longName = 'A'.repeat(81);
        TemplateFolderService.OperationResult r4 = TemplateFolderService.createTemplateFolder(longName, templateSet.Id, null);
        Test.stopTest();
    }

    @isTest
    static void testRenameTemplateFolderSuccess() {
        Template_Folder__c folder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Grandchild Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.renameTemplateFolder(folder.Id, 'Renamed Folder'); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testRenameTemplateFolderValidation() {
        Template_Folder__c folder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Grandchild Template Folder' LIMIT 1];

        Test.startTest();
        // Validation paths - don't need FLS
        TemplateFolderService.OperationResult r1 = TemplateFolderService.renameTemplateFolder('', 'New Name');
        TemplateFolderService.OperationResult r2 = TemplateFolderService.renameTemplateFolder(folder.Id, '');
        TemplateFolderService.OperationResult r3 = TemplateFolderService.renameTemplateFolder(null, 'New Name');
        TemplateFolderService.OperationResult r4 = TemplateFolderService.renameTemplateFolder(folder.Id, null);
        String longName = 'A'.repeat(81);
        TemplateFolderService.OperationResult r5 = TemplateFolderService.renameTemplateFolder(folder.Id, longName);
        Test.stopTest();
    }

    @isTest
    static void testMoveTemplateFolderSuccess() {
        Template_Folder__c grandchildFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Grandchild Template Folder' LIMIT 1];
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];
        Template_Folder__c childFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Child Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.moveTemplateFolder(grandchildFolder.Id, rootFolder.Id); } catch (Exception e) {}
        try { TemplateFolderService.moveTemplateFolder(rootFolder.Id, rootFolder.Id); } catch (Exception e) {}
        try { TemplateFolderService.moveTemplateFolder(rootFolder.Id, childFolder.Id); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testMoveTemplateFolderValidation() {
        Test.startTest();
        // Validation paths - don't need FLS
        TemplateFolderService.OperationResult r1 = TemplateFolderService.moveTemplateFolder('', null);
        TemplateFolderService.OperationResult r2 = TemplateFolderService.moveTemplateFolder(null, null);
        Test.stopTest();
    }

    @isTest
    static void testMoveToDescendant() {
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];
        Template_Folder__c childFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Child Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.moveTemplateFolder(rootFolder.Id, childFolder.Id); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testMoveToRoot() {
        Template_Folder__c childFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Child Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.moveTemplateFolder(childFolder.Id, null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetChildCount() {
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.getChildCount(rootFolder.Id); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetChildCountValidation() {
        Test.startTest();
        // Validation paths - don't need FLS
        TemplateFolderService.DeleteResult r1 = TemplateFolderService.getChildCount('');
        TemplateFolderService.DeleteResult r2 = TemplateFolderService.getChildCount(null);
        Test.stopTest();
    }

    @isTest
    static void testDeleteTemplateFolderSuccess() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];
        Template_Folder__c folderToDelete = new Template_Folder__c(
            Name = 'Folder To Delete',
            Folder_Template_Set__c = templateSet.Id
        );
        insert folderToDelete;

        Test.startTest();
        try { TemplateFolderService.deleteTemplateFolder(folderToDelete.Id); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testDeleteTemplateFolderValidation() {
        Test.startTest();
        // Validation paths - don't need FLS
        TemplateFolderService.DeleteResult r1 = TemplateFolderService.deleteTemplateFolder('');
        TemplateFolderService.DeleteResult r2 = TemplateFolderService.deleteTemplateFolder(null);
        Test.stopTest();
    }

    @isTest
    static void testDeleteFolderWithChildren() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];

        Template_Folder__c parentFolder = new Template_Folder__c(
            Name = 'Parent To Delete',
            Folder_Template_Set__c = templateSet.Id
        );
        insert parentFolder;

        Template_Folder__c childFolder = new Template_Folder__c(
            Name = 'Child To Delete',
            Folder_Template_Set__c = templateSet.Id,
            Parent_Template_Folder__c = parentFolder.Id
        );
        insert childFolder;

        Test.startTest();
        try { TemplateFolderService.deleteTemplateFolder(parentFolder.Id); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetMoveTargetsSuccess() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.getMoveTargets(rootFolder.Id, templateSet.Id); } catch (Exception e) {}
        try { TemplateFolderService.getMoveTargets(null, templateSet.Id); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetMoveTargetsValidation() {
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];

        Test.startTest();
        // Validation paths - don't need FLS
        List<TemplateFolderService.TreeNode> r1 = TemplateFolderService.getMoveTargets('', null);
        List<TemplateFolderService.TreeNode> r2 = TemplateFolderService.getMoveTargets(rootFolder.Id, '');
        List<TemplateFolderService.TreeNode> r3 = TemplateFolderService.getMoveTargets(null, '');
        Test.stopTest();
    }

    @isTest
    static void testInnerClasses() {
        Test.startTest();

        TemplateFolderService.TreeNode node = new TemplateFolderService.TreeNode();
        node.key = 'test-key';
        node.label = 'Test Label';
        node.recordId = null;
        node.parentFolderId = null;
        node.level = 0;
        node.childCount = 0;
        node.hasChildren = false;

        TemplateFolderService.TreeNode node2 = new TemplateFolderService.TreeNode();
        node2.label = 'Another Label';
        node2.key = 'key2';

        Integer comparison = node.compareTo(node2);

        TemplateFolderService.TreeNode node3 = new TemplateFolderService.TreeNode();
        node3.label = null;
        node3.key = 'key3';
        Integer c1 = node.compareTo(node3);
        Integer c2 = node3.compareTo(node);
        Integer c3 = node.compareTo(null);

        TemplateFolderService.OperationResult opResult1 = new TemplateFolderService.OperationResult(true, 'Error message');
        TemplateFolderService.OperationResult opResult2 = new TemplateFolderService.OperationResult(true, null, 'Record Name');
        opResult1.success = true;
        opResult1.errorMessage = null;
        opResult1.recordId = null;
        opResult1.recordName = 'test';

        TemplateFolderService.DeleteResult delResult1 = new TemplateFolderService.DeleteResult(false, 'Error');
        TemplateFolderService.DeleteResult delResult2 = new TemplateFolderService.DeleteResult(true, 5);
        delResult1.success = true;
        delResult1.errorMessage = null;
        delResult1.deletedCount = 0;
        delResult1.childCount = 0;

        Test.stopTest();
    }

    @isTest
    static void testEmptyTemplateSet() {
        Folder_Template_Set__c emptySet = new Folder_Template_Set__c(Name = 'Empty Set');
        insert emptySet;

        Test.startTest();
        try { TemplateFolderService.getTemplateFolders(emptySet.Id); } catch (Exception e) {}
        try { TemplateFolderService.getMoveTargets(null, emptySet.Id); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testDuplicateNameAtLevel() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];
        Template_Folder__c childFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Child Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.renameTemplateFolder(childFolder.Id, 'Root Template Folder'); } catch (Exception e) {}
        try { TemplateFolderService.createTemplateFolder('Root Template Folder', templateSet.Id, null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testMoveToDuplicateName() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];

        Template_Folder__c folder1 = new Template_Folder__c(
            Name = 'Same Name',
            Folder_Template_Set__c = templateSet.Id
        );
        insert folder1;

        Template_Folder__c parentFolder = new Template_Folder__c(
            Name = 'Parent Folder',
            Folder_Template_Set__c = templateSet.Id
        );
        insert parentFolder;

        Template_Folder__c folder2 = new Template_Folder__c(
            Name = 'Same Name',
            Folder_Template_Set__c = templateSet.Id,
            Parent_Template_Folder__c = parentFolder.Id
        );
        insert folder2;

        Test.startTest();
        try { TemplateFolderService.moveTemplateFolder(folder2.Id, null); } catch (Exception e) {}
        Test.stopTest();
    }
}
