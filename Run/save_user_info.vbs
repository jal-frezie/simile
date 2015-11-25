   Const ForReading = 1, ForWriting = 2, ForAppending = 8

   Dim fso, f
   Dim tokens
   Dim file
   
   file=Session.Property("CustomActionData")
   tokens=Split(file,"|")
   
   Set fso = CreateObject("Scripting.FileSystemObject")
   Set f = fso.OpenTextFile(tokens(0), ForWriting, True)

   f.WriteLine "gnu"   
   f.WriteLine "pipe"
   f.WriteLine "1275478189 :: Wed Jun 02 12:29:49 BST 2010"      
   f.WriteLine tokens(1)   
   f.WriteLine tokens(2)   
   f.WriteLine tokens(3)   
   f.WriteLine tokens(4)
   f.Close
