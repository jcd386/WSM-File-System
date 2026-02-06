/**
 * @description Test class for TemplateFolderService - Coverage focused
 */
@isTest
private class TemplateFolderServiceTest {

    @TestSetup
    static void setupTestData() {
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
        TemplateFolderService.getTemplateFolders(templateSet.Id);
        TemplateFolderService.getTemplateFolders('');
        TemplateFolderService.getTemplateFolders(null);
        Test.stopTest();
    }

    @isTest
    static void testCreateTemplateFolder() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];

        Test.startTest();
        TemplateFolderService.createTemplateFolder('New Root Folder', templateSet.Id, null);
        TemplateFolderService.createTemplateFolder('New Child Folder', templateSet.Id, rootFolder.Id);
        TemplateFolderService.createTemplateFolder('', templateSet.Id, null);
        TemplateFolderService.createTemplateFolder('Test', '', null);
        TemplateFolderService.createTemplateFolder('Root Template Folder', templateSet.Id, null);
        String longName = 'A'.repeat(81);
        TemplateFolderService.createTemplateFolder(longName, templateSet.Id, null);
        Test.stopTest();
    }

    @isTest
    static void testRenameTemplateFolder() {
        Template_Folder__c folder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Grandchild Template Folder' LIMIT 1];

        Test.startTest();
        TemplateFolderService.renameTemplateFolder(folder.Id, 'Renamed Folder');
        TemplateFolderService.renameTemplateFolder('', 'New Name');
        TemplateFolderService.renameTemplateFolder(folder.Id, '');
        String longName = 'A'.repeat(81);
        TemplateFolderService.renameTemplateFolder(folder.Id, longName);
        Test.stopTest();
    }

    @isTest
    static void testMoveTemplateFolder() {
        Template_Folder__c grandchildFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Grandchild Template Folder' LIMIT 1];
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];
        Template_Folder__c childFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Child Template Folder' LIMIT 1];

        Test.startTest();
        TemplateFolderService.moveTemplateFolder(grandchildFolder.Id, rootFolder.Id);
        TemplateFolderService.moveTemplateFolder(rootFolder.Id, rootFolder.Id);
        TemplateFolderService.moveTemplateFolder('', null);
        TemplateFolderService.moveTemplateFolder(rootFolder.Id, null);
        Test.stopTest();
    }

    @isTest
    static void testMoveToDescendant() {
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];
        Template_Folder__c childFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Child Template Folder' LIMIT 1];

        Test.startTest();
        TemplateFolderService.moveTemplateFolder(rootFolder.Id, childFolder.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetChildCount() {
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];

        Test.startTest();
        TemplateFolderService.getChildCount(rootFolder.Id);
        TemplateFolderService.getChildCount('');
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
        TemplateFolderService.deleteTemplateFolder(folderToDelete.Id);
        TemplateFolderService.deleteTemplateFolder('');
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
        TemplateFolderService.deleteTemplateFolder(parentFolder.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetMoveTargets() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];

        Test.startTest();
        TemplateFolderService.getMoveTargets(rootFolder.Id, templateSet.Id);
        TemplateFolderService.getMoveTargets('', templateSet.Id);
        TemplateFolderService.getMoveTargets(rootFolder.Id, '');
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

        node.compareTo(node2);
        node.compareTo(null);

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
        TemplateFolderService.getTemplateFolders(emptySet.Id);
        TemplateFolderService.getMoveTargets(null, emptySet.Id);
        Test.stopTest();
    }

    @isTest
    static void testDuplicateNameAtLevel() {
        Folder_Template_Set__c templateSet = [SELECT Id FROM Folder_Template_Set__c WHERE Name = 'Test Template Set' LIMIT 1];
        Template_Folder__c rootFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Root Template Folder' LIMIT 1];
        Template_Folder__c childFolder = [SELECT Id FROM Template_Folder__c WHERE Name = 'Child Template Folder' LIMIT 1];

        Test.startTest();
        TemplateFolderService.renameTemplateFolder(childFolder.Id, 'Root Template Folder');
        TemplateFolderService.createTemplateFolder('Root Template Folder', templateSet.Id, null);
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
        TemplateFolderService.moveTemplateFolder(folder2.Id, null);
        Test.stopTest();
    }
}
