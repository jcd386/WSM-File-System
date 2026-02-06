/**
 * @description Test class for WSMFolderTreeService - Coverage focused
 */
@isTest
private class WSMFolderTreeServiceTest {

    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Folder__c rootFolder = new Folder__c(
            Name = 'Root Folder',
            Parent_Id__c = testAccount.Id
        );
        insert rootFolder;

        Folder__c childFolder = new Folder__c(
            Name = 'Child Folder',
            Parent_Id__c = testAccount.Id,
            Parent_Folder__c = rootFolder.Id
        );
        insert childFolder;

        Folder__c grandchildFolder = new Folder__c(
            Name = 'Grandchild Folder',
            Parent_Id__c = testAccount.Id,
            Parent_Folder__c = childFolder.Id
        );
        insert grandchildFolder;

        File__c testFile = new File__c(
            Name = 'Test File.txt',
            Folder__c = childFolder.Id,
            File_URL__c = 'https://example.com/file.txt'
        );
        insert testFile;
    }

    @isTest
    static void testGetFolderContents() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];
        Folder__c childFolder = [SELECT Id FROM Folder__c WHERE Name = 'Child Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.getFolderContents(testAccount.Id, null);
        WSMFolderTreeService.getFolderContents(testAccount.Id, rootFolder.Id);
        WSMFolderTreeService.getFolderContents(testAccount.Id, childFolder.Id);
        try { WSMFolderTreeService.getFolderContents('', null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetFolderFileTree() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.getFolderFileTree(testAccount.Id);
        WSMFolderTreeService.getFolderFileTree('');
        WSMFolderTreeService.getFolderFileTree(null);
        Test.stopTest();
    }

    @isTest
    static void testGetParentFolderInfo() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.getParentFolderInfo(testAccount.Id);
        WSMFolderTreeService.getParentFolderInfo('');
        WSMFolderTreeService.getParentFolderInfo(null);
        Test.stopTest();
    }

    @isTest
    static void testGetFolderParentInfo() {
        Folder__c childFolder = [SELECT Id FROM Folder__c WHERE Name = 'Child Folder' LIMIT 1];
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.getFolderParentInfo(childFolder.Id);
        WSMFolderTreeService.getFolderParentInfo(rootFolder.Id);
        WSMFolderTreeService.getFolderParentInfo('');
        WSMFolderTreeService.getFolderParentInfo(null);
        Test.stopTest();
    }

    @isTest
    static void testGetFoldersForSelect() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.getFoldersForSelect(testAccount.Id);
        WSMFolderTreeService.getFoldersForSelect('');
        WSMFolderTreeService.getFoldersForSelect(null);
        Test.stopTest();
    }

    @isTest
    static void testCreateFolder() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.createFolder('New Folder 1', testAccount.Id, null);
        WSMFolderTreeService.createFolder('New Folder 2', testAccount.Id, rootFolder.Id);
        WSMFolderTreeService.createFolder('', testAccount.Id, null);
        WSMFolderTreeService.createFolder('Test', '', null);
        WSMFolderTreeService.createFolder('Root Folder', testAccount.Id, null);
        String longName = 'A'.repeat(81);
        WSMFolderTreeService.createFolder(longName, testAccount.Id, null);
        Test.stopTest();
    }

    @isTest
    static void testRenameFolder() {
        Folder__c folder = [SELECT Id FROM Folder__c WHERE Name = 'Grandchild Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.renameFolder(folder.Id, 'Renamed Folder');
        WSMFolderTreeService.renameFolder('', 'New Name');
        WSMFolderTreeService.renameFolder(folder.Id, '');
        String longName = 'A'.repeat(81);
        WSMFolderTreeService.renameFolder(folder.Id, longName);
        Test.stopTest();
    }

    @isTest
    static void testDeleteFolder() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Folder__c folderToDelete = new Folder__c(
            Name = 'Folder To Delete',
            Parent_Id__c = testAccount.Id
        );
        insert folderToDelete;

        Test.startTest();
        WSMFolderTreeService.deleteFolder(folderToDelete.Id);
        WSMFolderTreeService.deleteFolder('');
        Test.stopTest();
    }

    @isTest
    static void testDeleteFolderWithContents() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Folder__c parentFolder = new Folder__c(
            Name = 'Parent To Delete',
            Parent_Id__c = testAccount.Id
        );
        insert parentFolder;

        Folder__c childFolder = new Folder__c(
            Name = 'Child To Delete',
            Parent_Id__c = testAccount.Id,
            Parent_Folder__c = parentFolder.Id
        );
        insert childFolder;

        File__c fileInFolder = new File__c(
            Name = 'File To Delete.txt',
            Folder__c = parentFolder.Id
        );
        insert fileInFolder;

        Test.startTest();
        WSMFolderTreeService.deleteFolder(parentFolder.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetFolderContentsCount() {
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.getFolderContentsCount(rootFolder.Id);
        WSMFolderTreeService.getFolderContentsCount('');
        Test.stopTest();
    }

    @isTest
    static void testMoveFolder() {
        Folder__c grandchildFolder = [SELECT Id FROM Folder__c WHERE Name = 'Grandchild Folder' LIMIT 1];
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];
        Folder__c childFolder = [SELECT Id FROM Folder__c WHERE Name = 'Child Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.moveFolder(grandchildFolder.Id, rootFolder.Id);
        WSMFolderTreeService.moveFolder(rootFolder.Id, rootFolder.Id);
        WSMFolderTreeService.moveFolder('', null);
        WSMFolderTreeService.moveFolder(rootFolder.Id, childFolder.Id);
        Test.stopTest();
    }

    @isTest
    static void testMoveFolderToRoot() {
        Folder__c childFolder = [SELECT Id FROM Folder__c WHERE Name = 'Child Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.moveFolder(childFolder.Id, null);
        Test.stopTest();
    }

    @isTest
    static void testMoveFile() {
        File__c testFile = [SELECT Id FROM File__c WHERE Name = 'Test File.txt' LIMIT 1];
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];
        Folder__c childFolder = [SELECT Id FROM Folder__c WHERE Name = 'Child Folder' LIMIT 1];

        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Folder__c destFolder = new Folder__c(
            Name = 'Destination Folder',
            Parent_Id__c = testAccount.Id
        );
        insert destFolder;

        Test.startTest();
        WSMFolderTreeService.moveFile(testFile.Id, destFolder.Id);
        WSMFolderTreeService.moveFile('', rootFolder.Id);
        WSMFolderTreeService.moveFile(testFile.Id, '');
        WSMFolderTreeService.moveFile(testFile.Id, destFolder.Id);
        Test.stopTest();
    }

    @isTest
    static void testMoveFileDuplicateName() {
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        File__c file1 = new File__c(Name = 'Duplicate.txt', Folder__c = rootFolder.Id);
        insert file1;

        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Folder__c destFolder = new Folder__c(Name = 'Dest Folder', Parent_Id__c = testAccount.Id);
        insert destFolder;

        File__c existingFile = new File__c(Name = 'Duplicate.txt', Folder__c = destFolder.Id);
        insert existingFile;

        Test.startTest();
        WSMFolderTreeService.moveFile(file1.Id, destFolder.Id);
        Test.stopTest();
    }

    @isTest
    static void testDeleteFile() {
        Folder__c folder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];
        File__c fileToDelete = new File__c(
            Name = 'File To Delete.txt',
            Folder__c = folder.Id
        );
        insert fileToDelete;

        Test.startTest();
        WSMFolderTreeService.deleteFile(fileToDelete.Id);
        WSMFolderTreeService.deleteFile('');
        Test.stopTest();
    }

    @isTest
    static void testCreateFileRecord() {
        Folder__c folder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.createFileRecord('', folder.Id, 'docId', 'linkedId');
        WSMFolderTreeService.createFileRecord('file.txt', '', 'docId', 'linkedId');
        WSMFolderTreeService.createFileRecord('file.txt', folder.Id, '', 'linkedId');
        Test.stopTest();
    }

    @isTest
    static void testUploadFileFromBase64() {
        Folder__c folder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.uploadFileFromBase64('', 'base64content', folder.Id);
        WSMFolderTreeService.uploadFileFromBase64('file.txt', '', folder.Id);
        WSMFolderTreeService.uploadFileFromBase64('file.txt', 'base64content', '');
        WSMFolderTreeService.uploadFileFromBase64('test.txt', EncodingUtil.base64Encode(Blob.valueOf('test content')), folder.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetAllAccountRootFolders() {
        Test.startTest();
        WSMFolderTreeService.getAllAccountRootFolders();
        Test.stopTest();
    }

    @isTest
    static void testSearchFolders() {
        Test.startTest();
        WSMFolderTreeService.searchFolders('Root');
        WSMFolderTreeService.searchFolders('Child');
        WSMFolderTreeService.searchFolders('');
        WSMFolderTreeService.searchFolders('ZZZZNONEXISTENT');
        Test.stopTest();
    }

    @isTest
    static void testTreeNodeComparable() {
        WSMFolderTreeService.TreeNode folderNode = new WSMFolderTreeService.TreeNode();
        folderNode.nodeType = 'Folder';
        folderNode.label = 'B Folder';

        WSMFolderTreeService.TreeNode fileNode = new WSMFolderTreeService.TreeNode();
        fileNode.nodeType = 'File';
        fileNode.label = 'A File';

        WSMFolderTreeService.TreeNode nullNode = new WSMFolderTreeService.TreeNode();
        nullNode.label = null;

        Test.startTest();
        folderNode.compareTo(fileNode);
        folderNode.compareTo(null);
        folderNode.compareTo(nullNode);
        nullNode.compareTo(folderNode);
        Test.stopTest();
    }

    @isTest
    static void testFolderOptionComparable() {
        WSMFolderTreeService.FolderOption option1 = new WSMFolderTreeService.FolderOption('id1', 'Zebra');
        WSMFolderTreeService.FolderOption option2 = new WSMFolderTreeService.FolderOption('id2', 'Apple');
        WSMFolderTreeService.FolderOption option3 = new WSMFolderTreeService.FolderOption('id3', null);

        Test.startTest();
        option1.compareTo(option2);
        option1.compareTo(null);
        option3.compareTo(option1);
        Test.stopTest();
    }

    @isTest
    static void testInnerClasses() {
        Test.startTest();

        WSMFolderTreeService.FileUploadResult uploadResult = new WSMFolderTreeService.FileUploadResult();
        uploadResult.fileRecordId = null;
        uploadResult.fileName = 'test';
        uploadResult.success = true;
        uploadResult.errorMessage = null;

        WSMFolderTreeService.FolderCreationResult folderResult = new WSMFolderTreeService.FolderCreationResult();
        folderResult.folderId = null;
        folderResult.folderName = 'test';
        folderResult.success = true;
        folderResult.errorMessage = null;

        WSMFolderTreeService.FileMoveResult moveResult = new WSMFolderTreeService.FileMoveResult();
        moveResult.success = true;
        moveResult.errorMessage = null;
        moveResult.newFileName = 'test';

        WSMFolderTreeService.FileDeleteResult deleteResult = new WSMFolderTreeService.FileDeleteResult();
        deleteResult.success = true;
        deleteResult.errorMessage = null;

        WSMFolderTreeService.FolderDeleteResult folderDeleteResult = new WSMFolderTreeService.FolderDeleteResult();
        folderDeleteResult.success = true;
        folderDeleteResult.errorMessage = null;
        folderDeleteResult.deletedFolderCount = 1;
        folderDeleteResult.deletedFileCount = 0;

        WSMFolderTreeService.FolderContentsCount contentsCount = new WSMFolderTreeService.FolderContentsCount();
        contentsCount.success = true;
        contentsCount.folderCount = 1;
        contentsCount.fileCount = 0;
        contentsCount.errorMessage = null;

        WSMFolderTreeService.AccountFolderGroup accountGroup = new WSMFolderTreeService.AccountFolderGroup(null, 'Test Account');
        accountGroup.folders = new List<WSMFolderTreeService.TreeNode>();

        WSMFolderTreeService.FolderSearchResult searchResult = new WSMFolderTreeService.FolderSearchResult(null, 'test', 'path', null, 'Account');

        Test.stopTest();
    }

    @isTest
    static void testCrossRecordNavigation() {
        Account parentAccount = new Account(Name = 'Parent Account');
        insert parentAccount;

        Account childAccount = new Account(Name = 'Child Account', ParentId = parentAccount.Id);
        insert childAccount;

        Folder__c parentFolder = new Folder__c(Name = 'Parent Account Folder', Parent_Id__c = parentAccount.Id);
        insert parentFolder;

        Folder__c childFolder = new Folder__c(
            Name = 'Child Account Folder',
            Parent_Id__c = childAccount.Id,
            Parent_Folder__c = parentFolder.Id
        );
        insert childFolder;

        Test.startTest();
        WSMFolderTreeService.getFolderContents(childAccount.Id, null);
        WSMFolderTreeService.getParentFolderInfo(childAccount.Id);
        WSMFolderTreeService.getFolderContents(parentAccount.Id, parentFolder.Id);
        Test.stopTest();
    }
}
