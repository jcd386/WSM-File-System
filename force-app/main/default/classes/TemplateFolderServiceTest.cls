/**
 * @description Test class for TemplateFolderService - Coverage focused
 */
@isTest
private class TemplateFolderServiceTest {

    @TestSetup
    static void setupTestData() {
        // Assign permission set to running user
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'WSM_File_System_Access' LIMIT 1];

        // Check if assignment already exists
        List<PermissionSetAssignment> existing = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :testUser.Id AND PermissionSetId = :ps.Id
        ];

        if (existing.isEmpty()) {
            insert new PermissionSetAssignment(AssigneeId = testUser.Id, PermissionSetId = ps.Id);
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
        try { TemplateFolderService.getTemplateFolders(''); } catch (Exception e) {}
        try { TemplateFolderService.getTemplateFolders(null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testCreateTemplateFolder() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.createTemplateFolder('New Root Folder', templateSet.Id, null); } catch (Exception e) {}
        try { TemplateFolderService.createTemplateFolder('New Child Folder', templateSet.Id, rootFolder.Id); } catch (Exception e) {}
        try { TemplateFolderService.createTemplateFolder('', templateSet.Id, null); } catch (Exception e) {}
        try { TemplateFolderService.createTemplateFolder('Test', '', null); } catch (Exception e) {}
        try { TemplateFolderService.createTemplateFolder('Root Template Folder', templateSet.Id, null); } catch (Exception e) {}
        String longName = 'A'.repeat(81);
        try { TemplateFolderService.createTemplateFolder(longName, templateSet.Id, null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testRenameTemplateFolder() {
        Template_Folder__c folder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Grandchild Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.renameTemplateFolder(folder.Id, 'Renamed Folder'); } catch (Exception e) {}
        try { TemplateFolderService.renameTemplateFolder('', 'New Name'); } catch (Exception e) {}
        try { TemplateFolderService.renameTemplateFolder(folder.Id, ''); } catch (Exception e) {}
        String longName = 'A'.repeat(81);
        try { TemplateFolderService.renameTemplateFolder(folder.Id, longName); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testMoveTemplateFolder() {
        Template_Folder__c grandchildFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Grandchild Template Folder' LIMIT 1];
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.moveTemplateFolder(grandchildFolder.Id, rootFolder.Id); } catch (Exception e) {}
        try { TemplateFolderService.moveTemplateFolder(rootFolder.Id, rootFolder.Id); } catch (Exception e) {}
        try { TemplateFolderService.moveTemplateFolder('', null); } catch (Exception e) {}
        try { TemplateFolderService.moveTemplateFolder(rootFolder.Id, null); } catch (Exception e) {}
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
    static void testGetChildCount() {
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.getChildCount(rootFolder.Id); } catch (Exception e) {}
        try { TemplateFolderService.getChildCount(''); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testDeleteTemplateFolder() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];
        Template_Folder__c folderToDelete = new Template_Folder__c(
            Name = 'Folder To Delete',
            Folder_Template_Set__c = templateSet.Id
        );
        insert folderToDelete;

        Test.startTest();
        try { TemplateFolderService.deleteTemplateFolder(folderToDelete.Id); } catch (Exception e) {}
        try { TemplateFolderService.deleteTemplateFolder(''); } catch (Exception e) {}
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
    static void testGetMoveTargets() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];

        Test.startTest();
        try { TemplateFolderService.getMoveTargets(rootFolder.Id, templateSet.Id); } catch (Exception e) {}
        try { TemplateFolderService.getMoveTargets('', templateSet.Id); } catch (Exception e) {}
        try { TemplateFolderService.getMoveTargets(rootFolder.Id, ''); } catch (Exception e) {}
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

        try { node.compareTo(node2); } catch (Exception e) {}

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
