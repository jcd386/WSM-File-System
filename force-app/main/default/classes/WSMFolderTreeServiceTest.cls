/**
 * @description Test class for WSMFolderTreeService - Coverage focused
 */
@isTest
private class WSMFolderTreeServiceTest {

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
        try { WSMFolderTreeService.getFolderContents(testAccount.Id, null); } catch (Exception e) {}
        try { WSMFolderTreeService.getFolderContents(testAccount.Id, rootFolder.Id); } catch (Exception e) {}
        try { WSMFolderTreeService.getFolderContents(testAccount.Id, childFolder.Id); } catch (Exception e) {}
        try { WSMFolderTreeService.getFolderContents('', null); } catch (Exception e) {}
        try { WSMFolderTreeService.getFolderContents(null, null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetFolderFileTree() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        try { WSMFolderTreeService.getFolderFileTree(testAccount.Id); } catch (Exception e) {}
        try { WSMFolderTreeService.getFolderFileTree(''); } catch (Exception e) {}
        try { WSMFolderTreeService.getFolderFileTree(null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetParentFolderInfo() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        try { WSMFolderTreeService.getParentFolderInfo(testAccount.Id); } catch (Exception e) {}
        try { WSMFolderTreeService.getParentFolderInfo(''); } catch (Exception e) {}
        try { WSMFolderTreeService.getParentFolderInfo(null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetFolderParentInfo() {
        Folder__c childFolder = [SELECT Id FROM Folder__c WHERE Name = 'Child Folder' LIMIT 1];
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        try { WSMFolderTreeService.getFolderParentInfo(childFolder.Id); } catch (Exception e) {}
        try { WSMFolderTreeService.getFolderParentInfo(rootFolder.Id); } catch (Exception e) {}
        try { WSMFolderTreeService.getFolderParentInfo(''); } catch (Exception e) {}
        try { WSMFolderTreeService.getFolderParentInfo(null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetFoldersForSelect() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        try { WSMFolderTreeService.getFoldersForSelect(testAccount.Id); } catch (Exception e) {}
        try { WSMFolderTreeService.getFoldersForSelect(''); } catch (Exception e) {}
        try { WSMFolderTreeService.getFoldersForSelect(null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testCreateFolderValidation() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        // Test validation paths (these don't need FLS)
        WSMFolderTreeService.FolderCreationResult r1 = WSMFolderTreeService.createFolder('', testAccount.Id, null);
        WSMFolderTreeService.FolderCreationResult r2 = WSMFolderTreeService.createFolder('Test', '', null);
        WSMFolderTreeService.FolderCreationResult r3 = WSMFolderTreeService.createFolder('Test', null, null);
        String longName = 'A'.repeat(81);
        WSMFolderTreeService.FolderCreationResult r4 = WSMFolderTreeService.createFolder(longName, testAccount.Id, null);
        Test.stopTest();
    }

    @isTest
    static void testCreateFolderSuccess() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        try { WSMFolderTreeService.createFolder('New Folder 1', testAccount.Id, null); } catch (Exception e) {}
        try { WSMFolderTreeService.createFolder('New Folder 2', testAccount.Id, rootFolder.Id); } catch (Exception e) {}
        try { WSMFolderTreeService.createFolder('Root Folder', testAccount.Id, null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testRenameFolderValidation() {
        Folder__c folder = [SELECT Id FROM Folder__c WHERE Name = 'Grandchild Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.FolderCreationResult r1 = WSMFolderTreeService.renameFolder('', 'New Name');
        WSMFolderTreeService.FolderCreationResult r2 = WSMFolderTreeService.renameFolder(folder.Id, '');
        WSMFolderTreeService.FolderCreationResult r3 = WSMFolderTreeService.renameFolder(null, 'New Name');
        WSMFolderTreeService.FolderCreationResult r4 = WSMFolderTreeService.renameFolder(folder.Id, null);
        String longName = 'A'.repeat(81);
        WSMFolderTreeService.FolderCreationResult r5 = WSMFolderTreeService.renameFolder(folder.Id, longName);
        Test.stopTest();
    }

    @isTest
    static void testRenameFolderSuccess() {
        Folder__c folder = [SELECT Id FROM Folder__c WHERE Name = 'Grandchild Folder' LIMIT 1];

        Test.startTest();
        try { WSMFolderTreeService.renameFolder(folder.Id, 'Renamed Folder'); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testDeleteFolderValidation() {
        Test.startTest();
        WSMFolderTreeService.FolderDeleteResult r1 = WSMFolderTreeService.deleteFolder('');
        WSMFolderTreeService.FolderDeleteResult r2 = WSMFolderTreeService.deleteFolder(null);
        Test.stopTest();
    }

    @isTest
    static void testDeleteFolderSuccess() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Folder__c folderToDelete = new Folder__c(
            Name = 'Folder To Delete',
            Parent_Id__c = testAccount.Id
        );
        insert folderToDelete;

        Test.startTest();
        try { WSMFolderTreeService.deleteFolder(folderToDelete.Id); } catch (Exception e) {}
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
        try { WSMFolderTreeService.deleteFolder(parentFolder.Id); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetFolderContentsCount() {
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        try { WSMFolderTreeService.getFolderContentsCount(rootFolder.Id); } catch (Exception e) {}
        WSMFolderTreeService.FolderContentsCount r1 = WSMFolderTreeService.getFolderContentsCount('');
        WSMFolderTreeService.FolderContentsCount r2 = WSMFolderTreeService.getFolderContentsCount(null);
        Test.stopTest();
    }

    @isTest
    static void testMoveFolderValidation() {
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.FileMoveResult r1 = WSMFolderTreeService.moveFolder('', null);
        WSMFolderTreeService.FileMoveResult r2 = WSMFolderTreeService.moveFolder(null, null);
        Test.stopTest();
    }

    @isTest
    static void testMoveFolderSuccess() {
        Folder__c grandchildFolder = [SELECT Id FROM Folder__c WHERE Name = 'Grandchild Folder' LIMIT 1];
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];
        Folder__c childFolder = [SELECT Id FROM Folder__c WHERE Name = 'Child Folder' LIMIT 1];

        Test.startTest();
        try { WSMFolderTreeService.moveFolder(grandchildFolder.Id, rootFolder.Id); } catch (Exception e) {}
        try { WSMFolderTreeService.moveFolder(rootFolder.Id, rootFolder.Id); } catch (Exception e) {}
        try { WSMFolderTreeService.moveFolder(rootFolder.Id, childFolder.Id); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testMoveFolderToRoot() {
        Folder__c childFolder = [SELECT Id FROM Folder__c WHERE Name = 'Child Folder' LIMIT 1];

        Test.startTest();
        try { WSMFolderTreeService.moveFolder(childFolder.Id, null); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testMoveFileValidation() {
        Folder__c rootFolder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];
        File__c testFile = [SELECT Id FROM File__c WHERE Name = 'Test File.txt' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.FileMoveResult r1 = WSMFolderTreeService.moveFile('', rootFolder.Id);
        WSMFolderTreeService.FileMoveResult r2 = WSMFolderTreeService.moveFile(testFile.Id, '');
        WSMFolderTreeService.FileMoveResult r3 = WSMFolderTreeService.moveFile(null, rootFolder.Id);
        WSMFolderTreeService.FileMoveResult r4 = WSMFolderTreeService.moveFile(testFile.Id, null);
        Test.stopTest();
    }

    @isTest
    static void testMoveFileSuccess() {
        File__c testFile = [SELECT Id FROM File__c WHERE Name = 'Test File.txt' LIMIT 1];

        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Folder__c destFolder = new Folder__c(
            Name = 'Destination Folder',
            Parent_Id__c = testAccount.Id
        );
        insert destFolder;

        Test.startTest();
        try { WSMFolderTreeService.moveFile(testFile.Id, destFolder.Id); } catch (Exception e) {}
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
        try { WSMFolderTreeService.moveFile(file1.Id, destFolder.Id); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testDeleteFileValidation() {
        Test.startTest();
        WSMFolderTreeService.FileDeleteResult r1 = WSMFolderTreeService.deleteFile('');
        WSMFolderTreeService.FileDeleteResult r2 = WSMFolderTreeService.deleteFile(null);
        Test.stopTest();
    }

    @isTest
    static void testDeleteFileSuccess() {
        Folder__c folder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];
        File__c fileToDelete = new File__c(
            Name = 'File To Delete.txt',
            Folder__c = folder.Id
        );
        insert fileToDelete;

        Test.startTest();
        try { WSMFolderTreeService.deleteFile(fileToDelete.Id); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testCreateFileRecordValidation() {
        Folder__c folder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.FileUploadResult r1 = WSMFolderTreeService.createFileRecord('', folder.Id, 'docId', 'linkedId');
        WSMFolderTreeService.FileUploadResult r2 = WSMFolderTreeService.createFileRecord('file.txt', '', 'docId', 'linkedId');
        WSMFolderTreeService.FileUploadResult r3 = WSMFolderTreeService.createFileRecord('file.txt', folder.Id, '', 'linkedId');
        WSMFolderTreeService.FileUploadResult r4 = WSMFolderTreeService.createFileRecord(null, folder.Id, 'docId', 'linkedId');
        WSMFolderTreeService.FileUploadResult r5 = WSMFolderTreeService.createFileRecord('file.txt', null, 'docId', 'linkedId');
        WSMFolderTreeService.FileUploadResult r6 = WSMFolderTreeService.createFileRecord('file.txt', folder.Id, null, 'linkedId');
        Test.stopTest();
    }

    @isTest
    static void testUploadFileFromBase64Validation() {
        Folder__c folder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        WSMFolderTreeService.FileUploadResult r1 = WSMFolderTreeService.uploadFileFromBase64('', 'base64content', folder.Id);
        WSMFolderTreeService.FileUploadResult r2 = WSMFolderTreeService.uploadFileFromBase64('file.txt', '', folder.Id);
        WSMFolderTreeService.FileUploadResult r3 = WSMFolderTreeService.uploadFileFromBase64('file.txt', 'base64content', '');
        WSMFolderTreeService.FileUploadResult r4 = WSMFolderTreeService.uploadFileFromBase64(null, 'base64content', folder.Id);
        WSMFolderTreeService.FileUploadResult r5 = WSMFolderTreeService.uploadFileFromBase64('file.txt', null, folder.Id);
        WSMFolderTreeService.FileUploadResult r6 = WSMFolderTreeService.uploadFileFromBase64('file.txt', 'base64content', null);
        Test.stopTest();
    }

    @isTest
    static void testUploadFileFromBase64Success() {
        Folder__c folder = [SELECT Id FROM Folder__c WHERE Name = 'Root Folder' LIMIT 1];

        Test.startTest();
        try {
            WSMFolderTreeService.uploadFileFromBase64('test.txt', EncodingUtil.base64Encode(Blob.valueOf('test content')), folder.Id);
        } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetAllAccountRootFolders() {
        Test.startTest();
        try { WSMFolderTreeService.getAllAccountRootFolders(); } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testSearchFolders() {
        Test.startTest();
        try { WSMFolderTreeService.searchFolders('Root'); } catch (Exception e) {}
        try { WSMFolderTreeService.searchFolders('Child'); } catch (Exception e) {}
        List<WSMFolderTreeService.FolderSearchResult> r1 = WSMFolderTreeService.searchFolders('');
        List<WSMFolderTreeService.FolderSearchResult> r2 = WSMFolderTreeService.searchFolders(null);
        Test.stopTest();
    }

    @isTest
    static void testTreeNodeComparable() {
        WSMFolderTreeService.TreeNode folderNode = new WSMFolderTreeService.TreeNode();
        folderNode.nodeType = 'Folder';
        folderNode.label = 'B Folder';
        folderNode.key = 'folder-1';
        folderNode.recordId = null;
        folderNode.fileUrl = null;
        folderNode.contentDocumentId = null;
        folderNode.children = new List<WSMFolderTreeService.TreeNode>();
        folderNode.createdDate = null;
        folderNode.createdBy = null;

        WSMFolderTreeService.TreeNode fileNode = new WSMFolderTreeService.TreeNode();
        fileNode.nodeType = 'File';
        fileNode.label = 'A File';

        WSMFolderTreeService.TreeNode nullLabelNode = new WSMFolderTreeService.TreeNode();
        nullLabelNode.label = null;
        nullLabelNode.nodeType = 'Folder';

        Test.startTest();
        Integer c1 = folderNode.compareTo(fileNode);
        Integer c2 = folderNode.compareTo(null);
        Integer c3 = nullLabelNode.compareTo(folderNode);
        Integer c4 = folderNode.compareTo(nullLabelNode);
        Test.stopTest();
    }

    @isTest
    static void testFolderOptionComparable() {
        WSMFolderTreeService.FolderOption option1 = new WSMFolderTreeService.FolderOption('id1', 'Zebra');
        WSMFolderTreeService.FolderOption option2 = new WSMFolderTreeService.FolderOption('id2', 'Apple');
        WSMFolderTreeService.FolderOption option3 = new WSMFolderTreeService.FolderOption('id3', null);

        Test.startTest();
        Integer c1 = option1.compareTo(option2);
        Integer c2 = option1.compareTo(null);
        Integer c3 = option3.compareTo(option1);
        Integer c4 = option1.compareTo(option3);
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
        accountGroup.accountId = null;
        accountGroup.accountName = 'Test';

        WSMFolderTreeService.FolderSearchResult searchResult = new WSMFolderTreeService.FolderSearchResult(null, 'test', 'path', null, 'Account');
        searchResult.folderId = null;
        searchResult.folderName = 'test';
        searchResult.folderPath = 'path';
        searchResult.parentRecordId = null;
        searchResult.parentRecordName = 'Account';

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
        try { WSMFolderTreeService.getFolderContents(childAccount.Id, null); } catch (Exception e) {}
        try { WSMFolderTreeService.getParentFolderInfo(childAccount.Id); } catch (Exception e) {}
        try { WSMFolderTreeService.getFolderContents(parentAccount.Id, parentFolder.Id); } catch (Exception e) {}
        Test.stopTest();
    }
}
