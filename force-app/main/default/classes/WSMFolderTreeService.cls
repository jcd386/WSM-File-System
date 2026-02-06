/**
 * @description Service class for folder tree navigation in Lightning components.
 *              Provides methods to query folder/file hierarchies anchored to parent records.
 * @author WSM Development Team
 */
public with sharing class WSMFolderTreeService {

    // ─────────────────────────────────────────────────────────────────────────
    // CONSTANTS
    // ─────────────────────────────────────────────────────────────────────────

    // Node Type Constants
    @TestVisible private static final String NODE_TYPE_FOLDER = 'Folder';
    @TestVisible private static final String NODE_TYPE_FILE   = 'File';

    // Cached Schema Describe Results
    private static Map<String, Schema.SObjectType> globalDescribe;

    // Dynamic Object/Field Names (resolved at runtime based on namespace)
    private static String FOLDER_OBJECT;
    private static String FILE_OBJECT;
    private static String FOLDER_PARENT_FOLDER_FIELD;
    private static String FOLDER_ANCHOR_FIELD;
    private static String FILE_FOLDER_LOOKUP_FIELD;
    private static String FILE_URL_FIELD;
    private static Boolean namesInitialized = false;

    /**
     * @description Initializes object and field names with correct namespace prefix.
     *              Checks if namespaced objects exist, otherwise uses non-namespaced names.
     */
    private static void initializeObjectNames() {
        if (namesInitialized) {
            return;
        }

        Map<String, Schema.SObjectType> describe = getGlobalDescribe();

        // Check for namespaced version first (e.g., wsmdev__Folder__c)
        // We check by looking for any object ending with __Folder__c that's not just Folder__c
        String detectedNamespace = '';
        for (String objName : describe.keySet()) {
            if (objName.endsWith('__folder__c') && objName != 'folder__c') {
                // Extract namespace from object name (e.g., "wsmdev__folder__c" -> "wsmdev__")
                Integer idx = objName.indexOf('__folder__c');
                if (idx > 0) {
                    detectedNamespace = objName.substring(0, idx) + '__';
                    break;
                }
            }
        }

        // If no namespaced Folder__c found, check for namespaced File__c
        if (String.isBlank(detectedNamespace)) {
            for (String objName : describe.keySet()) {
                if (objName.endsWith('__file__c') && objName != 'file__c') {
                    Integer idx = objName.indexOf('__file__c');
                    if (idx > 0) {
                        detectedNamespace = objName.substring(0, idx) + '__';
                        break;
                    }
                }
            }
        }

        // Set object and field names with detected namespace (or empty string for non-namespaced)
        FOLDER_OBJECT = detectedNamespace + 'Folder__c';
        FILE_OBJECT = detectedNamespace + 'File__c';
        FOLDER_PARENT_FOLDER_FIELD = detectedNamespace + 'Parent_Folder__c';
        FOLDER_ANCHOR_FIELD = detectedNamespace + 'Parent_Id__c';
        FILE_FOLDER_LOOKUP_FIELD = detectedNamespace + 'Folder__c';
        FILE_URL_FIELD = detectedNamespace + 'File_URL__c';

        namesInitialized = true;
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // INNER CLASSES
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Represents a node in the folder/file tree structure.
     *              Implements Comparable to sort folders before files, then alphabetically.
     */
    public class TreeNode implements Comparable {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String nodeType;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String fileUrl;
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public List<TreeNode> children;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdBy;

        public Integer compareTo(Object otherObj) {
            if (otherObj == null) return 1;
            TreeNode other = (TreeNode)otherObj;

            Integer typeCmp = typeRank(this.nodeType) - typeRank(other.nodeType);
            if (typeCmp != 0) return typeCmp;

            String a = String.isBlank(this.label) ? '' : this.label.toLowerCase();
            String b = String.isBlank(other.label) ? '' : other.label.toLowerCase();
            return a.compareTo(b);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPER METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Returns cached global describe map for schema operations.
     * @return Map of object names to SObjectType
     */
    private static Map<String, Schema.SObjectType> getGlobalDescribe() {
        if (globalDescribe == null) {
            globalDescribe = Schema.getGlobalDescribe();
        }
        return globalDescribe;
    }

    /**
     * @description Returns sort rank for node types (folders first).
     * @param nodeType The type of node ('Folder' or 'File')
     * @return Integer rank value
     */
    private static Integer typeRank(String nodeType) {
        return (nodeType == NODE_TYPE_FOLDER) ? 0 : 1;
    }

    /**
     * @description Validates that required custom objects exist in the org.
     * @throws AuraHandledException if objects are not found
     */
    private static void validateObjectsExist() {
        // Initialize object names first (detects namespace)
        initializeObjectNames();

        Map<String, Schema.SObjectType> describe = getGlobalDescribe();
        if (!describe.containsKey(FOLDER_OBJECT.toLowerCase())) {
            throw new AuraHandledException('Folder object not found: ' + FOLDER_OBJECT + '. Ensure the WSM File System objects are deployed.');
        }
        if (!describe.containsKey(FILE_OBJECT.toLowerCase())) {
            throw new AuraHandledException('File object not found: ' + FILE_OBJECT + '. Ensure the WSM File System objects are deployed.');
        }
    }

    /**
     * @description Validates object-level security for folder and file objects.
     * @throws AuraHandledException if user lacks access
     */
    private static void validateObjectAccess() {
        // Ensure names are initialized
        initializeObjectNames();

        Map<String, Schema.SObjectType> describe = getGlobalDescribe();

        SObjectType folderObjType = describe.get(FOLDER_OBJECT.toLowerCase());
        SObjectType fileObjType = describe.get(FILE_OBJECT.toLowerCase());

        if (folderObjType == null || !folderObjType.getDescribe().isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access folder records.');
        }
        if (fileObjType == null || !fileObjType.getDescribe().isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access file records.');
        }
    }

    /**
     * @description Creates a TreeNode for a folder record.
     * @param folderId The folder record Id
     * @param folderName The folder name
     * @param includeChildren Whether to initialize children list
     * @return Configured TreeNode instance
     */
    private static TreeNode createFolderNode(Id folderId, String folderName, Boolean includeChildren) {
        TreeNode node = new TreeNode();
        node.key = 'folder-' + String.valueOf(folderId);
        node.label = folderName;
        node.nodeType = NODE_TYPE_FOLDER;
        node.recordId = folderId;
        node.children = includeChildren ? new List<TreeNode>() : null;
        return node;
    }

    /**
     * @description Creates a TreeNode for a file record.
     * @param fileId The file record Id
     * @param fileName The file name
     * @param fileUrl The file download URL (optional)
     * @param contentDocumentId The ContentDocument Id for file preview (optional)
     * @param createdDate The file record created date (optional)
     * @param createdByName The name of the user who created the file (optional)
     * @return Configured TreeNode instance
     */
    private static TreeNode createFileNode(Id fileId, String fileName, String fileUrl, String contentDocumentId, Datetime createdDate, String createdByName) {
        TreeNode node = new TreeNode();
        node.key = 'file-' + String.valueOf(fileId);
        node.label = fileName;
        node.nodeType = NODE_TYPE_FILE;
        node.recordId = fileId;
        node.fileUrl = fileUrl;
        node.contentDocumentId = contentDocumentId;
        node.children = null;
        node.createdDate = createdDate;
        node.createdBy = createdByName;
        return node;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC AURA-ENABLED METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Returns folder and file contents for a specific folder level.
     *              Used for lazy-loading folder tree navigation.
     * @param parentRecordId The anchor record Id (e.g., Account Id)
     * @param currentFolderId The current folder Id (null for root level)
     * @return List of TreeNode objects representing folders and files
     * @throws AuraHandledException if parentRecordId is blank or objects don't exist
     */
    @AuraEnabled
    public static List<TreeNode> getFolderContents(String parentRecordId, String currentFolderId) {
        if (String.isBlank(parentRecordId)) {
            throw new AuraHandledException('Parent record ID is required.');
        }

        // Validate objects exist and user has access
        validateObjectsExist();
        validateObjectAccess();

        List<TreeNode> results = new List<TreeNode>();

        if (String.isBlank(currentFolderId)) {
            // Root level navigation
            results = getRootFolderContents(parentRecordId);
        } else {
            // Subfolder level navigation
            results = getSubfolderContents(parentRecordId, currentFolderId);
        }

        results.sort();
        return results;
    }

    /**
     * @description Gets root-level folder contents for a parent record.
     * @param parentRecordId The anchor record Id
     * @return List of TreeNode objects for root folders
     */
    private static List<TreeNode> getRootFolderContents(String parentRecordId) {
        List<TreeNode> results = new List<TreeNode>();
        
        // First try to get folders where Parent_Folder__c = null
        String folderSoql =
            'SELECT Id, Name FROM ' + FOLDER_OBJECT +
            ' WHERE ' + FOLDER_ANCHOR_FIELD + ' = :parentRecordId' +
            ' AND ' + FOLDER_PARENT_FOLDER_FIELD + ' = null' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Name';
        
        List<SObject> rootFolders = Database.query(folderSoql);
        
        // If no root folders found, handle cross-record hierarchy case
        // (e.g., Opportunity folders nested under Account folder)
        if (rootFolders.isEmpty()) {
            return findEffectiveRootFolders(parentRecordId);
        }
        
        // Build folder nodes from standard root query
        for (SObject f : rootFolders) {
            results.add(createFolderNode((Id)f.get('Id'), (String)f.get('Name'), false));
        }
        
        return results;
    }

    /**
     * @description Finds effective root folders when no true roots exist.
     *              Handles cross-record folder hierarchies.
     * @param parentRecordId The anchor record Id
     * @return List of TreeNode objects for effective root folders
     */
    private static List<TreeNode> findEffectiveRootFolders(String parentRecordId) {
        List<TreeNode> results = new List<TreeNode>();
        
        String folderSoql =
            'SELECT Id, Name, ' + FOLDER_PARENT_FOLDER_FIELD +
            ' FROM ' + FOLDER_OBJECT +
            ' WHERE ' + FOLDER_ANCHOR_FIELD + ' = :parentRecordId' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Name';
        
        List<SObject> allFolders = Database.query(folderSoql);
        
        // Collect all folder IDs for this record
        Set<Id> allFolderIds = new Set<Id>();
        for (SObject f : allFolders) {
            allFolderIds.add((Id)f.get('Id'));
        }
        
        // Root folders are those with no parent OR whose parent is outside this record
        for (SObject f : allFolders) {
            Id folderId = (Id)f.get('Id');
            Id parentFolderId = (Id)f.get(FOLDER_PARENT_FOLDER_FIELD);
            
            if (parentFolderId == null || !allFolderIds.contains(parentFolderId)) {
                results.add(createFolderNode(folderId, (String)f.get('Name'), false));
            }
        }
        
        return results;
    }

    /**
     * @description Gets subfolder contents including cross-record folders and files.
     * @param parentRecordId The anchor record Id
     * @param currentFolderId The current folder Id
     * @return List of TreeNode objects for subfolders and files
     */
    private static List<TreeNode> getSubfolderContents(String parentRecordId, String currentFolderId) {
        List<TreeNode> results = new List<TreeNode>();
        
        // Query folders from current record
        String folderSoql =
            'SELECT Id, Name FROM ' + FOLDER_OBJECT +
            ' WHERE ' + FOLDER_ANCHOR_FIELD + ' = :parentRecordId' +
            ' AND ' + FOLDER_PARENT_FOLDER_FIELD + ' = :currentFolderId' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Name';

        List<SObject> folderRecs = Database.query(folderSoql);
        
        for (SObject f : folderRecs) {
            results.add(createFolderNode((Id)f.get('Id'), (String)f.get('Name'), false));
        }
        
        // Cross-record navigation: folders from OTHER records with this folder as parent
        String crossRecordSoql =
            'SELECT Id, Name FROM ' + FOLDER_OBJECT +
            ' WHERE ' + FOLDER_PARENT_FOLDER_FIELD + ' = :currentFolderId' +
            ' AND ' + FOLDER_ANCHOR_FIELD + ' != :parentRecordId' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Name';
        
        List<SObject> crossRecordFolders = Database.query(crossRecordSoql);
        
        for (SObject f : crossRecordFolders) {
            results.add(createFolderNode((Id)f.get('Id'), (String)f.get('Name'), false));
        }

        // Query files in current folder
        String fileSoql =
            'SELECT Id, Name, ' + FILE_URL_FIELD + ', CreatedDate, CreatedBy.Name FROM ' + FILE_OBJECT +
            ' WHERE ' + FILE_FOLDER_LOOKUP_FIELD + ' = :currentFolderId' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Name';

        List<SObject> fileRecs = Database.query(fileSoql);

        // Collect file IDs to query ContentDocumentLink
        Set<Id> fileIds = new Set<Id>();
        for (SObject fr : fileRecs) {
            fileIds.add((Id)fr.get('Id'));
        }

        // Query ContentDocumentLinks to get ContentDocumentIds for file preview
        Map<Id, Id> fileIdToContentDocId = getContentDocumentIdsForFiles(fileIds);

        for (SObject fr : fileRecs) {
            Id fileId = (Id)fr.get('Id');
            String contentDocId = fileIdToContentDocId.containsKey(fileId)
                ? String.valueOf(fileIdToContentDocId.get(fileId))
                : null;
            Datetime createdDate = (Datetime)fr.get('CreatedDate');
            String createdByName = null;
            SObject createdByUser = fr.getSObject('CreatedBy');
            if (createdByUser != null) {
                createdByName = (String)createdByUser.get('Name');
            }
            results.add(createFileNode(fileId, (String)fr.get('Name'), (String)fr.get(FILE_URL_FIELD), contentDocId, createdDate, createdByName));
        }

        return results;
    }

    /**
     * @description Gets cross-record parent folder information for navigation.
     *              Used to navigate up from a child record's folder to its parent record's folder.
     * @param parentRecordId The current anchor record Id
     * @return Map containing parentFolderId, parentFolderName, and parentRecordId if found
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getParentFolderInfo(String parentRecordId) {
        Map<String, Object> result = new Map<String, Object>();
        
        if (String.isBlank(parentRecordId)) {
            return result;
        }

        // Validate objects exist
        validateObjectsExist();

        // Query all folders for this record
        String folderSoql =
            'SELECT Id, Name, ' + FOLDER_PARENT_FOLDER_FIELD + ', ' + FOLDER_ANCHOR_FIELD +
            ' FROM ' + FOLDER_OBJECT +
            ' WHERE ' + FOLDER_ANCHOR_FIELD + ' = :parentRecordId' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Name';

        List<SObject> allFolders = Database.query(folderSoql);
        
        if (allFolders.isEmpty()) {
            return result;
        }

        // Collect all folder IDs for this record
        Set<Id> allFolderIds = new Set<Id>();
        for (SObject f : allFolders) {
            allFolderIds.add((Id)f.get('Id'));
        }
        
        // Find folder whose parent is outside this record's folder set (cross-record parent)
        Id crossRecordParentId = findCrossRecordParentId(allFolders, allFolderIds);
        
        if (crossRecordParentId != null) {
            result = getParentFolderDetails(crossRecordParentId);
        }
        
        return result;
    }

    /**
     * @description Finds the cross-record parent folder Id from a list of folders.
     * @param folders List of folder SObjects
     * @param localFolderIds Set of folder Ids belonging to the current record
     * @return The parent folder Id if found, null otherwise
     */
    private static Id findCrossRecordParentId(List<SObject> folders, Set<Id> localFolderIds) {
        for (SObject folder : folders) {
            Id parentFolderId = (Id)folder.get(FOLDER_PARENT_FOLDER_FIELD);
            
            // If parent exists and is NOT in this record's folder set
            if (parentFolderId != null && !localFolderIds.contains(parentFolderId)) {
                return parentFolderId;
            }
        }
        return null;
    }

    /**
     * @description Gets details for a parent folder.
     * @param parentFolderId The parent folder Id
     * @return Map containing folder details
     */
    private static Map<String, Object> getParentFolderDetails(Id parentFolderId) {
        Map<String, Object> result = new Map<String, Object>();
        
        String parentSoql =
            'SELECT Id, Name, ' + FOLDER_ANCHOR_FIELD +
            ' FROM ' + FOLDER_OBJECT +
            ' WHERE Id = :parentFolderId' +
            ' WITH SECURITY_ENFORCED' +
            ' LIMIT 1';
        
        List<SObject> parentFolders = Database.query(parentSoql);
        
        if (!parentFolders.isEmpty()) {
            SObject parentFolder = parentFolders[0];
            result.put('parentFolderId', parentFolder.get('Id'));
            result.put('parentFolderName', parentFolder.get('Name'));
            result.put('parentRecordId', parentFolder.get(FOLDER_ANCHOR_FIELD));
        }
        
        return result;
    }

    /**
     * @description Gets parent folder information for a specific folder.
     *              Used for breadcrumb navigation and folder context.
     * @param folderId The folder Id to get parent info for
     * @return Map containing parentFolderId, parentFolderName, parentRecordId, currentRecordId
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getFolderParentInfo(String folderId) {
        Map<String, Object> result = new Map<String, Object>();
        
        if (String.isBlank(folderId)) {
            return result;
        }

        // Validate objects exist
        validateObjectsExist();

        // Get the folder's parent info
        String folderSoql =
            'SELECT Id, Name, ' + FOLDER_PARENT_FOLDER_FIELD + ', ' + FOLDER_ANCHOR_FIELD +
            ' FROM ' + FOLDER_OBJECT +
            ' WHERE Id = :folderId' +
            ' WITH SECURITY_ENFORCED' +
            ' LIMIT 1';

        List<SObject> folders = Database.query(folderSoql);
        
        if (folders.isEmpty()) {
            return result;
        }

        SObject folder = folders[0];
        Id parentFolderId = (Id)folder.get(FOLDER_PARENT_FOLDER_FIELD);
        Id anchorRecordId = (Id)folder.get(FOLDER_ANCHOR_FIELD);
        
        if (parentFolderId != null) {
            result = getParentFolderDetails(parentFolderId);
            result.put('currentRecordId', anchorRecordId);
        }
        
        return result;
    }

    /**
     * @description Builds complete folder/file tree hierarchy for a parent record.
     *              Used for displaying full tree views (not lazy-loaded).
     * @param parentRecordId The anchor record Id
     * @return List of root TreeNode objects with nested children
     */
    @AuraEnabled(cacheable=true)
    public static List<TreeNode> getFolderFileTree(String parentRecordId) {
        if (String.isBlank(parentRecordId)) {
            return new List<TreeNode>();
        }

        // Validate objects exist and user has access
        validateObjectsExist();
        validateObjectAccess();

        // Query folders for this anchor with security enforced
        String folderSoql =
            'SELECT Id, Name, ' + FOLDER_PARENT_FOLDER_FIELD +
            ' FROM ' + FOLDER_OBJECT +
            ' WHERE ' + FOLDER_ANCHOR_FIELD + ' = :parentRecordId' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Name';

        List<SObject> folderRecs = Database.query(folderSoql);
        
        if (folderRecs.isEmpty()) {
            return new List<TreeNode>();
        }

        // Build folder node map and collect folder IDs
        Map<Id, TreeNode> folderNodeById = new Map<Id, TreeNode>();
        Set<Id> folderIds = new Set<Id>();
        
        for (SObject f : folderRecs) {
            Id folderId = (Id)f.get('Id');
            folderIds.add(folderId);
            folderNodeById.put(folderId, createFolderNode(folderId, (String)f.get('Name'), true));
        }

        // Build tree structure and identify root nodes
        List<TreeNode> roots = buildFolderHierarchy(folderRecs, folderNodeById);

        // Query and attach files to their folders
        attachFilesToFolders(folderIds, folderNodeById);

        // Sort recursively
        sortTree(roots);
        return roots;
    }

    /**
     * @description Builds folder hierarchy from flat list and identifies root nodes.
     * @param folderRecs List of folder SObjects
     * @param folderNodeById Map of folder Id to TreeNode
     * @return List of root TreeNode objects
     */
    private static List<TreeNode> buildFolderHierarchy(List<SObject> folderRecs, Map<Id, TreeNode> folderNodeById) {
        List<TreeNode> roots = new List<TreeNode>();
        
        for (SObject f : folderRecs) {
            Id folderId = (Id)f.get('Id');
            Id parentFolderId = (Id)f.get(FOLDER_PARENT_FOLDER_FIELD);
            TreeNode node = folderNodeById.get(folderId);

            if (parentFolderId != null && folderNodeById.containsKey(parentFolderId)) {
                folderNodeById.get(parentFolderId).children.add(node);
            } else {
                roots.add(node);
            }
        }
        
        return roots;
    }

    /**
     * @description Queries files and attaches them to their parent folder nodes.
     * @param folderIds Set of folder Ids to query files for
     * @param folderNodeById Map of folder Id to TreeNode
     */
    private static void attachFilesToFolders(Set<Id> folderIds, Map<Id, TreeNode> folderNodeById) {
        String fileSoql =
            'SELECT Id, Name, ' + FILE_FOLDER_LOOKUP_FIELD + ', ' + FILE_URL_FIELD + ', CreatedDate, CreatedBy.Name' +
            ' FROM ' + FILE_OBJECT +
            ' WHERE ' + FILE_FOLDER_LOOKUP_FIELD + ' IN :folderIds' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Name';

        List<SObject> fileRecs = Database.query(fileSoql);

        // Collect file IDs to query ContentDocumentLink
        Set<Id> fileIds = new Set<Id>();
        for (SObject fr : fileRecs) {
            fileIds.add((Id)fr.get('Id'));
        }

        // Query ContentDocumentLinks to get ContentDocumentIds for file preview
        Map<Id, Id> fileIdToContentDocId = getContentDocumentIdsForFiles(fileIds);

        for (SObject fr : fileRecs) {
            Id folderId = (Id)fr.get(FILE_FOLDER_LOOKUP_FIELD);
            TreeNode folderNode = folderNodeById.get(folderId);

            if (folderNode != null) {
                Id fileId = (Id)fr.get('Id');
                String contentDocId = fileIdToContentDocId.containsKey(fileId)
                    ? String.valueOf(fileIdToContentDocId.get(fileId))
                    : null;
                Datetime createdDate = (Datetime)fr.get('CreatedDate');
                String createdByName = null;
                SObject createdByUser = fr.getSObject('CreatedBy');
                if (createdByUser != null) {
                    createdByName = (String)createdByUser.get('Name');
                }
                folderNode.children.add(createFileNode(fileId, (String)fr.get('Name'), (String)fr.get(FILE_URL_FIELD), contentDocId, createdDate, createdByName));
            }
        }
    }
    
    /**
     * @description Queries ContentDocumentLink to get ContentDocumentIds for file records.
     * @param fileIds Set of File__c record Ids
     * @return Map of File__c Id to ContentDocument Id
     */
    private static Map<Id, Id> getContentDocumentIdsForFiles(Set<Id> fileIds) {
        Map<Id, Id> fileIdToContentDocId = new Map<Id, Id>();
        
        if (fileIds == null || fileIds.isEmpty()) {
            return fileIdToContentDocId;
        }
        
        // Query ContentDocumentLink where LinkedEntityId is the File__c record
        List<ContentDocumentLink> cdLinks = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :fileIds
            WITH SECURITY_ENFORCED
        ];
        
        for (ContentDocumentLink cdl : cdLinks) {
            // Only store the first ContentDocumentId for each file (in case of multiple)
            if (!fileIdToContentDocId.containsKey(cdl.LinkedEntityId)) {
                fileIdToContentDocId.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
            }
        }
        
        return fileIdToContentDocId;
    }

    /**
     * @description Recursively sorts tree nodes (folders first, then alphabetically).
     * @param nodes List of TreeNode objects to sort
     */
    private static void sortTree(List<TreeNode> nodes) {
        if (nodes == null || nodes.isEmpty()) {
            return;
        }
        nodes.sort();
        for (TreeNode node : nodes) {
            if (node.children != null && !node.children.isEmpty()) {
                sortTree(node.children);
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FILE UPLOAD METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Inner class to hold upload result information.
     */
    public class FileUploadResult {
        @AuraEnabled public Id fileRecordId;
        @AuraEnabled public String fileName;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }

    /**
     * @description Inner class for sortable folder options.
     */
    public class FolderOption implements Comparable {
        @AuraEnabled public String value;
        @AuraEnabled public String label;

        public FolderOption(String value, String label) {
            this.value = value;
            this.label = label;
        }

        public Integer compareTo(Object otherObj) {
            if (otherObj == null) return 1;
            FolderOption other = (FolderOption)otherObj;
            String a = String.isBlank(this.label) ? '' : this.label.toLowerCase();
            String b = String.isBlank(other.label) ? '' : other.label.toLowerCase();
            return a.compareTo(b);
        }
    }

    /**
     * @description Inner class to hold folder creation result information.
     */
    public class FolderCreationResult {
        @AuraEnabled public Id folderId;
        @AuraEnabled public String folderName;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }

    /**
     * @description Creates a File__c record and links the uploaded ContentDocument to it.
     *              Also removes the automatic ContentDocumentLink to the original upload record.
     * @param fileName The name to give the File__c record
     * @param folderId The folder Id to associate the file with
     * @param contentDocumentId The ContentDocument Id from the uploaded file
     * @param originalLinkedEntityId The original record Id where the file was uploaded (to remove the automatic link)
     * @return FileUploadResult with the created file record details
     * @throws AuraHandledException if required parameters are missing or operation fails
     */
    @AuraEnabled
    public static FileUploadResult createFileRecord(String fileName, String folderId, String contentDocumentId, String originalLinkedEntityId) {
        FileUploadResult result = new FileUploadResult();
        result.success = false;
        
        // Validate inputs
        if (String.isBlank(fileName)) {
            result.errorMessage = 'File name is required.';
            return result;
        }
        if (String.isBlank(folderId)) {
            result.errorMessage = 'Folder selection is required.';
            return result;
        }
        if (String.isBlank(contentDocumentId)) {
            result.errorMessage = 'Content document ID is required.';
            return result;
        }

        // Validate objects exist
        validateObjectsExist();
        
        // Check create permission on File object
        Map<String, Schema.SObjectType> describe = getGlobalDescribe();
        SObjectType fileObjType = describe.get(FILE_OBJECT.toLowerCase());
        if (!fileObjType.getDescribe().isCreateable()) {
            result.errorMessage = 'Insufficient permissions to create file records.';
            return result;
        }

        Savepoint sp = Database.setSavepoint();
        
        try {
            // Query ContentDocument to get the LatestPublishedVersionId for building the URL
            List<ContentDocument> contentDocs = [
                SELECT Id, LatestPublishedVersionId
                FROM ContentDocument
                WHERE Id = :contentDocumentId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            String fileUrl = '';
            if (!contentDocs.isEmpty() && contentDocs[0].LatestPublishedVersionId != null) {
                // Build the full Salesforce file download URL
                // Format: https://{domain}/sfc/servlet.shepherd/version/download/{versionId}
                String baseUrl = URL.getOrgDomainUrl().toExternalForm();
                fileUrl = baseUrl + '/sfc/servlet.shepherd/version/download/' + contentDocs[0].LatestPublishedVersionId;
            }
            
            // Create the File__c record
            SObject fileRecord = fileObjType.newSObject();
            fileRecord.put('Name', fileName);
            fileRecord.put(FILE_FOLDER_LOOKUP_FIELD, folderId);
            if (String.isNotBlank(fileUrl)) {
                fileRecord.put(FILE_URL_FIELD, fileUrl);
            }
            insert fileRecord;
            
            Id fileRecordId = (Id)fileRecord.get('Id');
            
            // Create ContentDocumentLink to associate the uploaded file with the File__c record
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocumentId;
            cdl.LinkedEntityId = fileRecordId;
            cdl.ShareType = 'V'; // Viewer permission
            cdl.Visibility = 'AllUsers';
            insert cdl;
            
            // Delete the automatic ContentDocumentLink to the original record (e.g., Opportunity)
            // This prevents the file from appearing in the Notes & Attachments related list
            if (String.isNotBlank(originalLinkedEntityId)) {
                List<ContentDocumentLink> autoLinks = [
                    SELECT Id
                    FROM ContentDocumentLink
                    WHERE ContentDocumentId = :contentDocumentId
                    AND LinkedEntityId = :originalLinkedEntityId
                    LIMIT 1
                ];
                if (!autoLinks.isEmpty()) {
                    delete autoLinks;
                }
            }
            
            result.fileRecordId = fileRecordId;
            result.fileName = fileName;
            result.success = true;
            
        } catch (Exception e) {
            Database.rollback(sp);
            result.errorMessage = 'Error creating file record: ' + e.getMessage();
        }
        
        return result;
    }

    /**
     * @description Creates a File__c record from base64 encoded content.
     *              Used for drag-and-drop file uploads in V2 component.
     *              Handles ContentVersion creation and ContentDocumentLink association.
     * @param fileName The name to give the file
     * @param base64Content The file content encoded as base64 string
     * @param folderId The folder Id to associate the file with
     * @return FileUploadResult with the created file record details
     * @throws AuraHandledException if required parameters are missing or operation fails
     */
    @AuraEnabled
    public static FileUploadResult uploadFileFromBase64(String fileName, String base64Content, String folderId) {
        FileUploadResult result = new FileUploadResult();
        result.success = false;

        // Validation
        if (String.isBlank(fileName)) {
            result.errorMessage = 'File name is required.';
            return result;
        }
        if (String.isBlank(base64Content)) {
            result.errorMessage = 'File content is required.';
            return result;
        }
        if (String.isBlank(folderId)) {
            result.errorMessage = 'Folder ID is required.';
            return result;
        }

        // Validate objects exist
        validateObjectsExist();

        // Check create permission on File object
        Map<String, Schema.SObjectType> describe = getGlobalDescribe();
        SObjectType fileObjType = describe.get(FILE_OBJECT.toLowerCase());
        if (!fileObjType.getDescribe().isCreateable()) {
            result.errorMessage = 'Insufficient permissions to create file records.';
            return result;
        }

        Savepoint sp = Database.setSavepoint();

        try {
            // 1. Create ContentVersion from base64 content
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Content);
            insert cv;

            // 2. Query to get ContentDocumentId
            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id WITH SECURITY_ENFORCED];

            // 3. Build file URL
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            String fileUrl = baseUrl + '/sfc/servlet.shepherd/version/download/' + cv.Id;

            // 4. Create File__c record
            SObject fileRecord = fileObjType.newSObject();
            fileRecord.put('Name', fileName);
            fileRecord.put(FILE_FOLDER_LOOKUP_FIELD, folderId);
            fileRecord.put(FILE_URL_FIELD, fileUrl);
            insert fileRecord;

            Id fileRecordId = (Id)fileRecord.get('Id');

            // 5. Create ContentDocumentLink to associate the file with the File__c record
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = fileRecordId;
            cdl.ShareType = 'V'; // Viewer permission
            cdl.Visibility = 'AllUsers';
            insert cdl;

            result.fileRecordId = fileRecordId;
            result.fileName = fileName;
            result.success = true;

        } catch (Exception e) {
            Database.rollback(sp);
            result.errorMessage = 'Error uploading file: ' + e.getMessage();
        }

        return result;
    }

    /**
     * @description Gets all folders for a parent record for folder selection dropdown.
     *              Returns flat list with folder path for display.
     * @param parentRecordId The anchor record Id
     * @return List of folder options with Id and display path
     */
    @AuraEnabled(cacheable=true)
    public static List<FolderOption> getFoldersForSelect(String parentRecordId) {
        System.debug('getFoldersForSelect called with parentRecordId: ' + parentRecordId);
        List<FolderOption> folderOptions = new List<FolderOption>();
        
        if (String.isBlank(parentRecordId)) {
            System.debug('parentRecordId is blank, returning empty list');
            return folderOptions;
        }

        // Validate objects exist and user has access
        validateObjectsExist();
        validateObjectAccess();

        // Query all folders for this anchor
        String folderSoql =
            'SELECT Id, Name, ' + FOLDER_PARENT_FOLDER_FIELD +
            ' FROM ' + FOLDER_OBJECT +
            ' WHERE ' + FOLDER_ANCHOR_FIELD + ' = :parentRecordId' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Name';

        System.debug('Executing SOQL: ' + folderSoql);
        List<SObject> folderRecs = Database.query(folderSoql);
        System.debug('Query returned ' + folderRecs.size() + ' folders');
        
        if (folderRecs.isEmpty()) {
            System.debug('No folders found for this record');
            return folderOptions;
        }

        // Build parent lookup map
        Map<Id, SObject> folderMap = new Map<Id, SObject>();
        for (SObject f : folderRecs) {
            Id fId = (Id)f.get('Id');
            folderMap.put(fId, f);
            System.debug('Added folder to map: ' + fId + ' - ' + f.get('Name'));
        }

        // Build folder options with paths
        for (SObject f : folderRecs) {
            try {
                String folderId = (String)f.get('Id');
                String folderName = (String)f.get('Name');
                System.debug('Building path for folder: ' + folderId + ' - ' + folderName);
                
                String folderPath = buildFolderPath(f, folderMap);
                System.debug('Built path: ' + folderPath);
                
                folderOptions.add(new FolderOption(folderId, folderPath));
            } catch (Exception e) {
                System.debug('Error building folder option: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
                // Use just the folder name if path building fails
                String folderId = (String)f.get('Id');
                String folderName = (String)f.get('Name');
                folderOptions.add(new FolderOption(folderId, folderName != null ? folderName : 'Unknown'));
            }
        }

        // Sort by label (path) - FolderOption implements Comparable
        folderOptions.sort();
        System.debug('Returning ' + folderOptions.size() + ' folder options');
        
        return folderOptions;
    }

    /**
     * @description Builds the full path string for a folder.
     * @param folder The folder SObject
     * @param folderMap Map of all folders by Id
     * @return The full path string (e.g., "Parent / Child / Grandchild")
     */
    private static String buildFolderPath(SObject folder, Map<Id, SObject> folderMap) {
        if (folder == null) {
            return '';
        }
        
        List<String> pathParts = new List<String>();
        SObject current = folder;
        Set<Id> visited = new Set<Id>(); // Prevent infinite loops
        Integer maxDepth = 50; // Safety limit
        Integer depth = 0;
        
        while (current != null && depth < maxDepth) {
            depth++;
            Id currentId = (Id)current.get('Id');
            
            if (currentId == null) {
                System.debug('Warning: current folder has null Id');
                break;
            }
            
            if (visited.contains(currentId)) {
                System.debug('Circular reference detected at folder: ' + currentId);
                break;
            }
            visited.add(currentId);
            
            String folderName = (String)current.get('Name');
            if (String.isNotBlank(folderName)) {
                // Append to end of list instead of inserting at 0
                pathParts.add(folderName);
            }
            
            Id parentId = (Id)current.get(FOLDER_PARENT_FOLDER_FIELD);
            if (parentId != null && folderMap.containsKey(parentId)) {
                current = folderMap.get(parentId);
            } else {
                current = null;
            }
        }
        
        // Reverse the list since we built it leaf-to-root
        List<String> reversedPath = new List<String>();
        for (Integer i = pathParts.size() - 1; i >= 0; i--) {
            reversedPath.add(pathParts[i]);
        }

        return String.join(reversedPath, ' / ');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FOLDER CREATION METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Creates a new Folder__c record with validation.
     * @param folderName The name for the new folder
     * @param anchorRecordId The parent record Id (Account, Opportunity, etc.)
     * @param parentFolderId The parent folder Id (null for root level)
     * @return FolderCreationResult with created folder details
     * @throws AuraHandledException if validation fails or user lacks permissions
     */
    @AuraEnabled
    public static FolderCreationResult createFolder(String folderName, String anchorRecordId, String parentFolderId) {
        FolderCreationResult result = new FolderCreationResult();
        result.success = false;

        // Validation
        if (String.isBlank(folderName)) {
            result.errorMessage = 'Folder name is required.';
            return result;
        }

        if (String.isBlank(anchorRecordId)) {
            result.errorMessage = 'Anchor record ID is required.';
            return result;
        }

        if (folderName.length() > 80) {
            result.errorMessage = 'Folder name must be 80 characters or less.';
            return result;
        }

        // Check for duplicate folder names at the same level
        String duplicateCheckSoql =
            'SELECT Id FROM ' + FOLDER_OBJECT +
            ' WHERE ' + FOLDER_ANCHOR_FIELD + ' = :anchorRecordId' +
            ' AND Name = :folderName';

        if (String.isNotBlank(parentFolderId)) {
            duplicateCheckSoql += ' AND ' + FOLDER_PARENT_FOLDER_FIELD + ' = :parentFolderId';
        } else {
            duplicateCheckSoql += ' AND ' + FOLDER_PARENT_FOLDER_FIELD + ' = null';
        }

        duplicateCheckSoql += ' WITH SECURITY_ENFORCED LIMIT 1';

        List<SObject> existingFolders = Database.query(duplicateCheckSoql);
        if (!existingFolders.isEmpty()) {
            result.errorMessage = 'A folder with this name already exists at this level.';
            return result;
        }

        // Validate objects exist
        validateObjectsExist();

        // Check create permission
        Map<String, Schema.SObjectType> describe = getGlobalDescribe();
        SObjectType folderObjType = describe.get(FOLDER_OBJECT.toLowerCase());
        if (!folderObjType.getDescribe().isCreateable()) {
            result.errorMessage = 'Insufficient permissions to create folders.';
            return result;
        }

        Savepoint sp = Database.setSavepoint();

        try {
            // Create folder record
            SObject folder = folderObjType.newSObject();
            folder.put('Name', folderName);
            folder.put(FOLDER_ANCHOR_FIELD, anchorRecordId);
            if (String.isNotBlank(parentFolderId)) {
                folder.put(FOLDER_PARENT_FOLDER_FIELD, parentFolderId);
            }
            insert folder;

            result.folderId = (Id)folder.get('Id');
            result.folderName = folderName;
            result.success = true;

        } catch (Exception e) {
            Database.rollback(sp);
            result.errorMessage = 'Error creating folder: ' + e.getMessage();
        }

        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FILE MOVE METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Inner class to hold file move result information.
     */
    public class FileMoveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String newFileName;
    }

    /**
     * @description Inner class to hold file delete result information.
     */
    public class FileDeleteResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }

    /**
     * @description Inner class representing an account with its root folders.
     */
    public class AccountFolderGroup {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public List<TreeNode> folders;

        public AccountFolderGroup(Id accountId, String accountName) {
            this.accountId = accountId;
            this.accountName = accountName;
            this.folders = new List<TreeNode>();
        }
    }

    /**
     * @description Gets all account root folders organized by account for modal navigation.
     *              Returns accounts with their top-level folders for cross-account navigation.
     * @return List of AccountFolderGroup objects with folders organized by account
     * @throws AuraHandledException if validation fails or user lacks permissions
     */
    @AuraEnabled(cacheable=true)
    public static List<AccountFolderGroup> getAllAccountRootFolders() {
        // Validate objects exist and user has access
        validateObjectsExist();
        validateObjectAccess();

        // Query all folders where Parent_Id__c is an Account and Parent_Folder__c is null (true root folders)
        String folderSoql =
            'SELECT Id, Name, ' + FOLDER_ANCHOR_FIELD +
            ' FROM ' + FOLDER_OBJECT +
            ' WHERE ' + FOLDER_PARENT_FOLDER_FIELD + ' = null' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Name';

        List<SObject> rootFolders = Database.query(folderSoql);

        if (rootFolders.isEmpty()) {
            return new List<AccountFolderGroup>();
        }

        // Collect unique account IDs
        Set<Id> accountIds = new Set<Id>();
        for (SObject folder : rootFolders) {
            Id parentId = (Id)folder.get(FOLDER_ANCHOR_FIELD);
            if (parentId != null && String.valueOf(parentId).startsWith('001')) {
                accountIds.add(parentId);
            }
        }

        // Query account names
        Map<Id, String> accountIdToName = new Map<Id, String>();
        if (!accountIds.isEmpty()) {
            List<Account> accounts = [
                SELECT Id, Name
                FROM Account
                WHERE Id IN :accountIds
                WITH SECURITY_ENFORCED
            ];

            for (Account acc : accounts) {
                accountIdToName.put(acc.Id, acc.Name);
            }
        }

        // Group folders by account
        Map<Id, AccountFolderGroup> accountGroups = new Map<Id, AccountFolderGroup>();
        for (SObject folder : rootFolders) {
            Id parentId = (Id)folder.get(FOLDER_ANCHOR_FIELD);

            // Only include Account-anchored folders
            if (parentId != null && String.valueOf(parentId).startsWith('001')) {
                if (!accountGroups.containsKey(parentId)) {
                    String accountName = accountIdToName.containsKey(parentId)
                        ? accountIdToName.get(parentId)
                        : 'Unknown Account';
                    accountGroups.put(parentId, new AccountFolderGroup(parentId, accountName));
                }

                TreeNode folderNode = createFolderNode(
                    (Id)folder.get('Id'),
                    (String)folder.get('Name'),
                    false
                );
                accountGroups.get(parentId).folders.add(folderNode);
            }
        }

        // Convert map to sorted list
        List<AccountFolderGroup> result = accountGroups.values();
        result.sort(new AccountFolderGroupComparator());

        return result;
    }

    /**
     * @description Comparator for sorting AccountFolderGroup by account name.
     */
    private class AccountFolderGroupComparator implements Comparator<AccountFolderGroup> {
        public Integer compare(AccountFolderGroup a, AccountFolderGroup b) {
            if (a == null && b == null) return 0;
            if (a == null) return -1;
            if (b == null) return 1;

            String nameA = String.isBlank(a.accountName) ? '' : a.accountName.toLowerCase();
            String nameB = String.isBlank(b.accountName) ? '' : b.accountName.toLowerCase();
            return nameA.compareTo(nameB);
        }
    }

    /**
     * @description Inner class representing a folder search result with full path.
     */
    public class FolderSearchResult {
        @AuraEnabled public Id folderId;
        @AuraEnabled public String folderName;
        @AuraEnabled public String folderPath;
        @AuraEnabled public Id parentRecordId;
        @AuraEnabled public String parentRecordName;

        public FolderSearchResult(Id folderId, String folderName, String folderPath, Id parentRecordId, String parentRecordName) {
            this.folderId = folderId;
            this.folderName = folderName;
            this.folderPath = folderPath;
            this.parentRecordId = parentRecordId;
            this.parentRecordName = parentRecordName;
        }
    }

    /**
     * @description Searches folders by name and path.
     *              Returns folders where the name or path contains the search term.
     * @param searchTerm The term to search for (case-insensitive)
     * @return List of FolderSearchResult objects with matching folders
     * @throws AuraHandledException if validation fails or user lacks permissions
     */
    @AuraEnabled(cacheable=true)
    public static List<FolderSearchResult> searchFolders(String searchTerm) {
        List<FolderSearchResult> results = new List<FolderSearchResult>();

        if (String.isBlank(searchTerm)) {
            return results;
        }

        // Validate objects exist and user has access
        validateObjectsExist();
        validateObjectAccess();

        // Query all folders with names matching the search term (using LIKE for partial match)
        String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        String folderSoql =
            'SELECT Id, Name, ' + FOLDER_PARENT_FOLDER_FIELD + ', ' + FOLDER_ANCHOR_FIELD +
            ' FROM ' + FOLDER_OBJECT +
            ' WHERE Name LIKE :searchPattern' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Name' +
            ' LIMIT 200';

        List<SObject> matchingFolders = Database.query(folderSoql);

        if (matchingFolders.isEmpty()) {
            return results;
        }

        // Collect all folder IDs to query complete hierarchy
        Set<Id> allFolderIds = new Set<Id>();
        for (SObject folder : matchingFolders) {
            allFolderIds.add((Id)folder.get('Id'));
            Id parentId = (Id)folder.get(FOLDER_PARENT_FOLDER_FIELD);
            if (parentId != null) {
                allFolderIds.add(parentId);
            }
        }

        // Query all folders needed to build complete paths
        String allFoldersSoql =
            'SELECT Id, Name, ' + FOLDER_PARENT_FOLDER_FIELD + ', ' + FOLDER_ANCHOR_FIELD +
            ' FROM ' + FOLDER_OBJECT +
            ' WHERE Id IN :allFolderIds' +
            ' WITH SECURITY_ENFORCED';

        List<SObject> allFolders = Database.query(allFoldersSoql);
        Map<Id, SObject> folderMap = new Map<Id, SObject>();
        for (SObject folder : allFolders) {
            folderMap.put((Id)folder.get('Id'), folder);
        }

        // Get parent record names (Account, Opportunity, etc.)
        Set<Id> parentRecordIds = new Set<Id>();
        for (SObject folder : matchingFolders) {
            Id parentRecordId = (Id)folder.get(FOLDER_ANCHOR_FIELD);
            if (parentRecordId != null) {
                parentRecordIds.add(parentRecordId);
            }
        }

        Map<Id, String> parentRecordNames = getParentRecordNames(parentRecordIds);

        // Build search results with full paths
        String lowerSearchTerm = searchTerm.toLowerCase();
        for (SObject folder : matchingFolders) {
            Id folderId = (Id)folder.get('Id');
            String folderName = (String)folder.get('Name');
            String folderPath = buildFolderPath(folder, folderMap);
            Id parentRecordId = (Id)folder.get(FOLDER_ANCHOR_FIELD);
            String parentRecordName = parentRecordNames.containsKey(parentRecordId)
                ? parentRecordNames.get(parentRecordId)
                : 'Unknown';

            // Include if name matches OR path matches
            if (folderName.toLowerCase().contains(lowerSearchTerm) ||
                folderPath.toLowerCase().contains(lowerSearchTerm)) {
                results.add(new FolderSearchResult(
                    folderId,
                    folderName,
                    folderPath,
                    parentRecordId,
                    parentRecordName
                ));
            }
        }

        return results;
    }

    /**
     * @description Gets display names for parent records (Account, Opportunity, etc.).
     * @param recordIds Set of record Ids
     * @return Map of record Id to display name
     */
    private static Map<Id, String> getParentRecordNames(Set<Id> recordIds) {
        Map<Id, String> recordNames = new Map<Id, String>();

        if (recordIds == null || recordIds.isEmpty()) {
            return recordNames;
        }

        // Separate IDs by object type
        Set<Id> accountIds = new Set<Id>();
        Set<Id> opportunityIds = new Set<Id>();
        Set<Id> otherIds = new Set<Id>();

        for (Id recordId : recordIds) {
            if (recordId == null) continue;

            String idPrefix = String.valueOf(recordId).substring(0, 3);
            if (idPrefix == '001') {
                accountIds.add(recordId);
            } else if (idPrefix == '006') {
                opportunityIds.add(recordId);
            } else {
                otherIds.add(recordId);
            }
        }

        // Query Accounts
        if (!accountIds.isEmpty()) {
            List<Account> accounts = [
                SELECT Id, Name
                FROM Account
                WHERE Id IN :accountIds
                WITH SECURITY_ENFORCED
            ];
            for (Account acc : accounts) {
                recordNames.put(acc.Id, acc.Name);
            }
        }

        // Query Opportunities
        if (!opportunityIds.isEmpty()) {
            List<Opportunity> opps = [
                SELECT Id, Name
                FROM Opportunity
                WHERE Id IN :opportunityIds
                WITH SECURITY_ENFORCED
            ];
            for (Opportunity opp : opps) {
                recordNames.put(opp.Id, opp.Name);
            }
        }

        return recordNames;
    }

    /**
     * @description Moves a file to a different folder with duplicate handling.
     *              If a file with the same name exists, appends (1), (2), etc.
     * @param fileId The File__c record Id to move
     * @param destinationFolderId The target Folder__c Id
     * @return FileMoveResult with success status and any updated filename
     * @throws AuraHandledException if validation fails or user lacks permissions
     */
    @AuraEnabled
    public static FileMoveResult moveFile(String fileId, String destinationFolderId) {
        FileMoveResult result = new FileMoveResult();
        result.success = false;

        // Validation
        if (String.isBlank(fileId)) {
            result.errorMessage = 'File ID is required.';
            return result;
        }

        if (String.isBlank(destinationFolderId)) {
            result.errorMessage = 'Destination folder ID is required.';
            return result;
        }

        // Validate objects exist
        validateObjectsExist();

        // Check update permission on File object
        Map<String, Schema.SObjectType> describe = getGlobalDescribe();
        SObjectType fileObjType = describe.get(FILE_OBJECT.toLowerCase());
        if (!fileObjType.getDescribe().isUpdateable()) {
            result.errorMessage = 'Insufficient permissions to move files.';
            return result;
        }

        Savepoint sp = Database.setSavepoint();

        try {
            // Query the file to get current folder and name
            String fileSoql =
                'SELECT Id, Name, ' + FILE_FOLDER_LOOKUP_FIELD +
                ' FROM ' + FILE_OBJECT +
                ' WHERE Id = :fileId' +
                ' WITH SECURITY_ENFORCED' +
                ' LIMIT 1';

            List<SObject> files = Database.query(fileSoql);

            if (files.isEmpty()) {
                result.errorMessage = 'File not found or you do not have access.';
                return result;
            }

            SObject fileRecord = files[0];
            Id currentFolderId = (Id)fileRecord.get(FILE_FOLDER_LOOKUP_FIELD);
            String originalFileName = (String)fileRecord.get('Name');

            // Check if moving to current location
            if (currentFolderId == destinationFolderId) {
                result.errorMessage = 'File is already in this folder.';
                return result;
            }

            // Check for duplicate file names in destination folder
            String newFileName = getUniqueFileName(originalFileName, destinationFolderId);

            // Update the file record
            fileRecord.put(FILE_FOLDER_LOOKUP_FIELD, destinationFolderId);
            if (newFileName != originalFileName) {
                fileRecord.put('Name', newFileName);
            }
            update fileRecord;

            result.success = true;
            result.newFileName = newFileName;

        } catch (Exception e) {
            Database.rollback(sp);
            result.errorMessage = 'Error moving file: ' + e.getMessage();
        }

        return result;
    }

    /**
     * @description Generates a unique filename by appending (1), (2), etc. if duplicates exist.
     * @param originalFileName The original file name
     * @param folderId The target folder Id
     * @return A unique filename for the destination folder
     */
    private static String getUniqueFileName(String originalFileName, Id folderId) {
        if (String.isBlank(originalFileName)) {
            return originalFileName;
        }

        // Query existing file names in the destination folder
        String existingFilesSoql =
            'SELECT Name FROM ' + FILE_OBJECT +
            ' WHERE ' + FILE_FOLDER_LOOKUP_FIELD + ' = :folderId' +
            ' WITH SECURITY_ENFORCED';

        List<SObject> existingFiles = Database.query(existingFilesSoql);

        // Build set of existing names
        Set<String> existingNames = new Set<String>();
        for (SObject f : existingFiles) {
            String name = (String)f.get('Name');
            if (String.isNotBlank(name)) {
                existingNames.add(name.toLowerCase());
            }
        }

        // If no duplicate, return original name
        if (!existingNames.contains(originalFileName.toLowerCase())) {
            return originalFileName;
        }

        // Find unique name by appending (1), (2), etc.
        String baseName = originalFileName;
        String extension = '';

        // Extract extension if present
        Integer lastDotIndex = originalFileName.lastIndexOf('.');
        if (lastDotIndex > 0 && lastDotIndex < originalFileName.length() - 1) {
            baseName = originalFileName.substring(0, lastDotIndex);
            extension = originalFileName.substring(lastDotIndex);
        }

        // Try appending numbers until we find a unique name
        Integer counter = 1;
        String candidateName = baseName + ' (' + counter + ')' + extension;

        while (existingNames.contains(candidateName.toLowerCase()) && counter < 1000) {
            counter++;
            candidateName = baseName + ' (' + counter + ')' + extension;
        }

        return candidateName;
    }

    /**
     * @description Deletes a File__c record.
     *              Performs permission checks before deletion.
     * @param fileId The File__c record Id to delete
     * @return FileDeleteResult with success status and error message if failed
     * @throws AuraHandledException if validation fails or user lacks permissions
     */
    @AuraEnabled
    public static FileDeleteResult deleteFile(String fileId) {
        FileDeleteResult result = new FileDeleteResult();
        result.success = false;

        // Validation
        if (String.isBlank(fileId)) {
            result.errorMessage = 'File ID is required.';
            return result;
        }

        // Validate objects exist
        validateObjectsExist();

        // Check delete permission on File object
        Map<String, Schema.SObjectType> describe = getGlobalDescribe();
        SObjectType fileObjType = describe.get(FILE_OBJECT.toLowerCase());
        if (!fileObjType.getDescribe().isDeletable()) {
            result.errorMessage = 'Insufficient permissions to delete files.';
            return result;
        }

        Savepoint sp = Database.setSavepoint();

        try {
            // Query the file to verify it exists and user has access
            String fileSoql =
                'SELECT Id, Name FROM ' + FILE_OBJECT +
                ' WHERE Id = :fileId' +
                ' WITH SECURITY_ENFORCED' +
                ' LIMIT 1';

            List<SObject> files = Database.query(fileSoql);

            if (files.isEmpty()) {
                result.errorMessage = 'File not found or you do not have access.';
                return result;
            }

            SObject fileRecord = files[0];

            // Delete the File__c record
            delete fileRecord;

            result.success = true;

        } catch (DmlException e) {
            Database.rollback(sp);
            result.errorMessage = 'Error deleting file: ' + e.getDmlMessage(0);
        } catch (Exception e) {
            Database.rollback(sp);
            result.errorMessage = 'Error deleting file: ' + e.getMessage();
        }

        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FOLDER OPERATIONS METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Inner class to hold folder delete result with counts.
     */
    public class FolderDeleteResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Integer deletedFolderCount;
        @AuraEnabled public Integer deletedFileCount;
    }

    /**
     * @description Inner class to hold folder contents count for delete confirmation.
     */
    public class FolderContentsCount {
        @AuraEnabled public Integer folderCount;
        @AuraEnabled public Integer fileCount;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }

    /**
     * @description Gets the count of all contents within a folder (for delete confirmation).
     * @param folderId The folder Id to count contents for
     * @return FolderContentsCount with folder and file counts
     */
    @AuraEnabled
    public static FolderContentsCount getFolderContentsCount(String folderId) {
        FolderContentsCount result = new FolderContentsCount();
        result.success = false;
        result.folderCount = 0;
        result.fileCount = 0;

        if (String.isBlank(folderId)) {
            result.errorMessage = 'Folder ID is required.';
            return result;
        }

        validateObjectsExist();

        try {
            // Get all descendant folder IDs
            Set<Id> allFolderIds = getAllDescendantFolderIds(folderId);
            result.folderCount = allFolderIds.size();

            // Add the target folder itself to count files
            allFolderIds.add(folderId);

            // Count files in all folders
            String fileCountSoql =
                'SELECT COUNT() FROM ' + FILE_OBJECT +
                ' WHERE ' + FILE_FOLDER_LOOKUP_FIELD + ' IN :allFolderIds' +
                ' WITH SECURITY_ENFORCED';

            result.fileCount = Database.countQuery(fileCountSoql);
            result.success = true;

        } catch (Exception e) {
            result.errorMessage = 'Error counting folder contents: ' + e.getMessage();
        }

        return result;
    }

    /**
     * @description Recursively gets all descendant folder IDs for a given folder.
     * @param parentFolderId The parent folder Id
     * @return Set of all descendant folder Ids
     */
    private static Set<Id> getAllDescendantFolderIds(String parentFolderId) {
        Set<Id> allDescendants = new Set<Id>();
        Set<Id> currentLevel = new Set<Id>();
        currentLevel.add(parentFolderId);

        Integer maxIterations = 50; // Safety limit for depth
        Integer iteration = 0;

        while (!currentLevel.isEmpty() && iteration < maxIterations) {
            iteration++;

            String childFolderSoql =
                'SELECT Id FROM ' + FOLDER_OBJECT +
                ' WHERE ' + FOLDER_PARENT_FOLDER_FIELD + ' IN :currentLevel' +
                ' WITH SECURITY_ENFORCED';

            List<SObject> childFolders = Database.query(childFolderSoql);

            Set<Id> nextLevel = new Set<Id>();
            for (SObject folder : childFolders) {
                Id childId = (Id)folder.get('Id');
                if (!allDescendants.contains(childId)) {
                    allDescendants.add(childId);
                    nextLevel.add(childId);
                }
            }
            currentLevel = nextLevel;
        }

        return allDescendants;
    }

    /**
     * @description Renames a folder with duplicate name checking.
     * @param folderId The folder Id to rename
     * @param newName The new name for the folder
     * @return FolderCreationResult with success status
     */
    @AuraEnabled
    public static FolderCreationResult renameFolder(String folderId, String newName) {
        FolderCreationResult result = new FolderCreationResult();
        result.success = false;

        // Validation
        if (String.isBlank(folderId)) {
            result.errorMessage = 'Folder ID is required.';
            return result;
        }

        if (String.isBlank(newName)) {
            result.errorMessage = 'Folder name is required.';
            return result;
        }

        if (newName.length() > 80) {
            result.errorMessage = 'Folder name must be 80 characters or less.';
            return result;
        }

        validateObjectsExist();

        // Check update permission
        Map<String, Schema.SObjectType> describe = getGlobalDescribe();
        SObjectType folderObjType = describe.get(FOLDER_OBJECT.toLowerCase());
        if (!folderObjType.getDescribe().isUpdateable()) {
            result.errorMessage = 'Insufficient permissions to rename folders.';
            return result;
        }

        Savepoint sp = Database.setSavepoint();

        try {
            // Query the folder to get its parent info
            String folderSoql =
                'SELECT Id, Name, ' + FOLDER_PARENT_FOLDER_FIELD + ', ' + FOLDER_ANCHOR_FIELD +
                ' FROM ' + FOLDER_OBJECT +
                ' WHERE Id = :folderId' +
                ' WITH SECURITY_ENFORCED' +
                ' LIMIT 1';

            List<SObject> folders = Database.query(folderSoql);

            if (folders.isEmpty()) {
                result.errorMessage = 'Folder not found or you do not have access.';
                return result;
            }

            SObject folder = folders[0];
            Id parentFolderId = (Id)folder.get(FOLDER_PARENT_FOLDER_FIELD);
            Id anchorRecordId = (Id)folder.get(FOLDER_ANCHOR_FIELD);

            // Check for duplicate names at the same level
            String duplicateCheckSoql =
                'SELECT Id FROM ' + FOLDER_OBJECT +
                ' WHERE ' + FOLDER_ANCHOR_FIELD + ' = :anchorRecordId' +
                ' AND Name = :newName' +
                ' AND Id != :folderId';

            if (parentFolderId != null) {
                duplicateCheckSoql += ' AND ' + FOLDER_PARENT_FOLDER_FIELD + ' = :parentFolderId';
            } else {
                duplicateCheckSoql += ' AND ' + FOLDER_PARENT_FOLDER_FIELD + ' = null';
            }

            duplicateCheckSoql += ' WITH SECURITY_ENFORCED LIMIT 1';

            List<SObject> duplicates = Database.query(duplicateCheckSoql);
            if (!duplicates.isEmpty()) {
                result.errorMessage = 'A folder with this name already exists at this level.';
                return result;
            }

            // Update the folder name
            folder.put('Name', newName);
            update folder;

            result.folderId = folderId;
            result.folderName = newName;
            result.success = true;

        } catch (Exception e) {
            Database.rollback(sp);
            result.errorMessage = 'Error renaming folder: ' + e.getMessage();
        }

        return result;
    }

    /**
     * @description Deletes a folder and all its contents (cascade delete).
     * @param folderId The folder Id to delete
     * @return FolderDeleteResult with success status and counts
     */
    @AuraEnabled
    public static FolderDeleteResult deleteFolder(String folderId) {
        FolderDeleteResult result = new FolderDeleteResult();
        result.success = false;
        result.deletedFolderCount = 0;
        result.deletedFileCount = 0;

        if (String.isBlank(folderId)) {
            result.errorMessage = 'Folder ID is required.';
            return result;
        }

        validateObjectsExist();

        // Check delete permissions
        Map<String, Schema.SObjectType> describe = getGlobalDescribe();
        SObjectType folderObjType = describe.get(FOLDER_OBJECT.toLowerCase());
        SObjectType fileObjType = describe.get(FILE_OBJECT.toLowerCase());

        if (!folderObjType.getDescribe().isDeletable()) {
            result.errorMessage = 'Insufficient permissions to delete folders.';
            return result;
        }

        if (!fileObjType.getDescribe().isDeletable()) {
            result.errorMessage = 'Insufficient permissions to delete files.';
            return result;
        }

        Savepoint sp = Database.setSavepoint();

        try {
            // Get all descendant folder IDs
            Set<Id> allDescendantIds = getAllDescendantFolderIds(folderId);

            // Create set including the target folder for file deletion
            Set<Id> allFolderIds = new Set<Id>(allDescendantIds);
            allFolderIds.add(folderId);

            // Delete all files in all folders first
            String fileDeleteSoql =
                'SELECT Id FROM ' + FILE_OBJECT +
                ' WHERE ' + FILE_FOLDER_LOOKUP_FIELD + ' IN :allFolderIds' +
                ' WITH SECURITY_ENFORCED';

            List<SObject> filesToDelete = Database.query(fileDeleteSoql);
            if (!filesToDelete.isEmpty()) {
                delete filesToDelete;
                result.deletedFileCount = filesToDelete.size();
            }

            // Delete descendant folders (need to delete in reverse order - deepest first)
            // Since we collected them level by level, we can delete them in reverse
            if (!allDescendantIds.isEmpty()) {
                String descendantDeleteSoql =
                    'SELECT Id FROM ' + FOLDER_OBJECT +
                    ' WHERE Id IN :allDescendantIds' +
                    ' WITH SECURITY_ENFORCED';

                List<SObject> descendantsToDelete = Database.query(descendantDeleteSoql);
                if (!descendantsToDelete.isEmpty()) {
                    delete descendantsToDelete;
                    result.deletedFolderCount = descendantsToDelete.size();
                }
            }

            // Delete the target folder
            String targetFolderSoql =
                'SELECT Id FROM ' + FOLDER_OBJECT +
                ' WHERE Id = :folderId' +
                ' WITH SECURITY_ENFORCED' +
                ' LIMIT 1';

            List<SObject> targetFolders = Database.query(targetFolderSoql);
            if (!targetFolders.isEmpty()) {
                delete targetFolders[0];
                result.deletedFolderCount++;
            }

            result.success = true;

        } catch (DmlException e) {
            Database.rollback(sp);
            result.errorMessage = 'Error deleting folder: ' + e.getDmlMessage(0);
        } catch (Exception e) {
            Database.rollback(sp);
            result.errorMessage = 'Error deleting folder: ' + e.getMessage();
        }

        return result;
    }

    /**
     * @description Moves a folder to a new parent folder.
     * @param folderId The folder Id to move
     * @param destinationFolderId The destination parent folder Id (null for root level)
     * @return FileMoveResult with success status
     */
    @AuraEnabled
    public static FileMoveResult moveFolder(String folderId, String destinationFolderId) {
        FileMoveResult result = new FileMoveResult();
        result.success = false;

        if (String.isBlank(folderId)) {
            result.errorMessage = 'Folder ID is required.';
            return result;
        }

        validateObjectsExist();

        // Check update permission
        Map<String, Schema.SObjectType> describe = getGlobalDescribe();
        SObjectType folderObjType = describe.get(FOLDER_OBJECT.toLowerCase());
        if (!folderObjType.getDescribe().isUpdateable()) {
            result.errorMessage = 'Insufficient permissions to move folders.';
            return result;
        }

        Savepoint sp = Database.setSavepoint();

        try {
            // Query the folder to move
            String folderSoql =
                'SELECT Id, Name, ' + FOLDER_PARENT_FOLDER_FIELD + ', ' + FOLDER_ANCHOR_FIELD +
                ' FROM ' + FOLDER_OBJECT +
                ' WHERE Id = :folderId' +
                ' WITH SECURITY_ENFORCED' +
                ' LIMIT 1';

            List<SObject> folders = Database.query(folderSoql);

            if (folders.isEmpty()) {
                result.errorMessage = 'Folder not found or you do not have access.';
                return result;
            }

            SObject folder = folders[0];
            Id currentParentId = (Id)folder.get(FOLDER_PARENT_FOLDER_FIELD);
            String folderName = (String)folder.get('Name');

            // Cannot move to self
            if (folderId == destinationFolderId) {
                result.errorMessage = 'Cannot move a folder into itself.';
                return result;
            }

            // Cannot move to same location
            if (currentParentId == destinationFolderId ||
                (currentParentId == null && String.isBlank(destinationFolderId))) {
                result.errorMessage = 'Folder is already in this location.';
                return result;
            }

            // Check that destination is not a descendant of the folder being moved
            if (String.isNotBlank(destinationFolderId)) {
                Set<Id> descendants = getAllDescendantFolderIds(folderId);
                if (descendants.contains(destinationFolderId)) {
                    result.errorMessage = 'Cannot move a folder into one of its subfolders.';
                    return result;
                }

                // Get destination folder's anchor record
                String destFolderSoql =
                    'SELECT Id, ' + FOLDER_ANCHOR_FIELD +
                    ' FROM ' + FOLDER_OBJECT +
                    ' WHERE Id = :destinationFolderId' +
                    ' WITH SECURITY_ENFORCED' +
                    ' LIMIT 1';

                List<SObject> destFolders = Database.query(destFolderSoql);
                if (destFolders.isEmpty()) {
                    result.errorMessage = 'Destination folder not found.';
                    return result;
                }

                Id destAnchorId = (Id)destFolders[0].get(FOLDER_ANCHOR_FIELD);

                // Check for duplicate name at destination
                String duplicateCheckSoql =
                    'SELECT Id FROM ' + FOLDER_OBJECT +
                    ' WHERE ' + FOLDER_ANCHOR_FIELD + ' = :destAnchorId' +
                    ' AND ' + FOLDER_PARENT_FOLDER_FIELD + ' = :destinationFolderId' +
                    ' AND Name = :folderName' +
                    ' AND Id != :folderId' +
                    ' WITH SECURITY_ENFORCED LIMIT 1';

                List<SObject> duplicates = Database.query(duplicateCheckSoql);
                if (!duplicates.isEmpty()) {
                    result.errorMessage = 'A folder with this name already exists in the destination.';
                    return result;
                }

                // Update folder with new parent and anchor
                folder.put(FOLDER_PARENT_FOLDER_FIELD, destinationFolderId);
                folder.put(FOLDER_ANCHOR_FIELD, destAnchorId);
            } else {
                // Moving to root - keep same anchor but clear parent
                folder.put(FOLDER_PARENT_FOLDER_FIELD, null);

                // Check for duplicate at root level
                Id anchorId = (Id)folder.get(FOLDER_ANCHOR_FIELD);
                String duplicateCheckSoql =
                    'SELECT Id FROM ' + FOLDER_OBJECT +
                    ' WHERE ' + FOLDER_ANCHOR_FIELD + ' = :anchorId' +
                    ' AND ' + FOLDER_PARENT_FOLDER_FIELD + ' = null' +
                    ' AND Name = :folderName' +
                    ' AND Id != :folderId' +
                    ' WITH SECURITY_ENFORCED LIMIT 1';

                List<SObject> duplicates = Database.query(duplicateCheckSoql);
                if (!duplicates.isEmpty()) {
                    result.errorMessage = 'A folder with this name already exists at the root level.';
                    return result;
                }
            }

            update folder;

            result.success = true;
            result.newFileName = folderName;

        } catch (Exception e) {
            Database.rollback(sp);
            result.errorMessage = 'Error moving folder: ' + e.getMessage();
        }

        return result;
    }
}