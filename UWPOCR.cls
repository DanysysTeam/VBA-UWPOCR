VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "UWPOCR"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'''' Copyright
'    Copyright 2024 Danysys. <hello@danysys.com>
'    Licensed under the MIT license.
'    See LICENSE file or go to https://opensource.org/licenses/MIT for details.
'''' Copyright

'''' Information
'    Author(s)......: DanysysTeam (Danyfirex & Dany3j)
'    Description....: UWP OCR Universal Windows Platform Optical character recognition
'    Remarks........: The current implementation is designed for using under Windows 10
'    Version........: 1.0.0
'    Thanks to .....:
'                     Jaafar Tribak - vtblCall - https://www.mrexcel.com/board/threads/late-bound-windows-media-player-going-out-of-scope.1245903/post-6110097

'''' Information


Option Explicit


Private Type GUID
    Data1 As Long
    Data2 As Integer
    Data3 As Integer
    Data4(0 To 7) As Byte
End Type

Private Type RECT
    x As Single
    Y As Single
    Width As Single
    Height As Single
End Type

#If VBA7 Then
    Private Declare PtrSafe Sub CopyMemory Lib "Kernel32" Alias "RtlMoveMemory" (Destination As Any, Source As Any, ByVal Length As LongPtr)
    Private Declare PtrSafe Function DispCallFunc Lib "oleAut32.dll" (ByVal pvInstance As LongPtr, ByVal offsetinVft As LongPtr, ByVal CallConv As Long, ByVal retTYP As Integer, ByVal paCNT As Long, ByRef paTypes As Integer, ByRef paValues As LongPtr, ByRef retVAR As Variant) As Long
    Private Declare PtrSafe Sub SetLastError Lib "kernel32.dll" (ByVal dwErrCode As Long)
    Private Declare PtrSafe Function CLSIDFromString Lib "ole32" (ByVal OleStringCLSID As LongPtr, ByRef cGUID As Any) As Long
    Private Declare PtrSafe Function RoGetActivationFactory Lib "Combase.dll" (ByVal activatableClassId As LongPtr, ByRef riid As GUID, ByRef factory As LongPtr) As Long
    Private Declare PtrSafe Function WindowsCreateString Lib "Combase.dll" (ByVal sourceString As LongPtr, ByVal Length As Long, ByRef hString As LongPtr) As Long
    Private Declare PtrSafe Function WindowsDeleteString Lib "Combase.dll" (ByVal sourceString As LongPtr) As Long
    Private Declare PtrSafe Function WindowsGetStringRawBuffer Lib "Combase.dll" (ByVal hString As LongPtr, ByRef Length As Long) As LongPtr
    Private Declare PtrSafe Function CreateRandomAccessStreamOnFile Lib "Shcore.dll" (ByVal pFilePath As LongPtr, ByVal Access As Long, ByRef riid As GUID, ByRef ppv As LongPtr) As Long
#Else
    Private Enum LongPtr
        [_]
    End Enum

    Private Declare Sub CopyMemory Lib "Kernel32" Alias "RtlMoveMemory" (Destination As Any, Source As Any, ByVal Length As Long)
    Private Declare Function DispCallFunc Lib "oleAut32.dll" (ByVal pvInstance As Long, ByVal offsetinVft As Long, ByVal CallConv As Long, ByVal retTYP As Integer, ByVal paCNT As Long, ByRef paTypes As Integer, ByRef paValues As Long, ByRef retVAR As Variant) As Long
    Private Declare Sub SetLastError Lib "kernel32.dll" (ByVal dwErrCode As Long)
    Private Declare Function CLSIDFromString Lib "ole32" (ByVal OleStringCLSID As Long, ByRef cGUID As Any) As Long
    Private Declare Function RoGetActivationFactory Lib "Combase.dll" (ByVal activatableClassId As Long, ByRef riid As GUID, ByRef factory As Long) As Long
    Private Declare Function WindowsCreateString Lib "Combase.dll" (ByVal sourceString As Long, ByVal Length As Long, ByRef hString As Long) As Long
    Private Declare Function WindowsDeleteString Lib "Combase.dll" (ByVal sourceString As LongPtr) As Long
    Private Declare Function WindowsGetStringRawBuffer Lib "Combase.dll" (ByVal hString As Long, ByRef Length As Long) As Long
    Private Declare Function CreateRandomAccessStreamOnFile Lib "Shcore.dll" (ByVal pFilePath As Long, ByVal Access As Long, ByRef riid As GUID, ByRef ppv As Long) As Long
#End If


#If Win64 Then
    Private Const PTR_SIZE As Long = 8
#Else
    Private Const PTR_SIZE As Long = 4
#End If

Private Const CC_STDCALL = 4
Private pILanguageFactory As LongPtr
Private pIGlobalizationPreferencesStatics As LongPtr
Private pIOcrEngineStatics As LongPtr
Private pIBitmapDecoderStatics As LongPtr
Private pIOcrEngine As LongPtr

Private CurrentLanguage As String
Private IsInitialized As Boolean
Private Languages As Collection

Private Sub Initialize()
    pILanguageFactory = RoGetActivationIFactory("Windows.Globalization.Language", "{9B0252AC-0C27-44F8-B792-9793FB66C63E}") 'IID_ILanguageFactory
    pIGlobalizationPreferencesStatics = RoGetActivationIFactory("Windows.System.UserProfile.GlobalizationPreferences", "{01BF4326-ED37-4E96-B0E9-C1340D1EA158}") 'IID_IGlobalizationPreferencesStatics
    pIOcrEngineStatics = RoGetActivationIFactory("Windows.Media.Ocr.OcrEngine", "{5BFFA85A-3384-3540-9940-699120D428A8}") 'IID_IOcrEngineStatics
    pIBitmapDecoderStatics = RoGetActivationIFactory("Windows.Graphics.Imaging.BitmapDecoder", "{438CCB26-BCEF-4E95-BAD6-23A822E58D01}") 'IID_IBitmapDecoderStatics
    
    If pILanguageFactory <> 0 And pIGlobalizationPreferencesStatics <> 0 And pIOcrEngineStatics <> 0 And pIBitmapDecoderStatics <> 0 Then
        IsInitialized = True
    End If
End Sub

Public Function ImageToText(ByVal PathImage As String, Optional ByVal Language As String = "", Optional ByVal UseLines As Boolean = False, Optional ByVal ReturnWordsArray As Boolean = False) As Variant
    Dim Result As String
    Dim ResultArray() As Variant
    ReDim ResultArray(0)
    
    If Not IsInitialized Then
        Initialize
    End If
    
    If Languages Is Nothing Then
        Call GetSupportedLanguages
    End If
    
    If Language = "" And Languages.Count > 0 Then
        Language = Languages.Item(1)(0)
    End If
    
    If Language <> "" And Languages.Count > 0 Then
        Dim Supported As Boolean
        Dim Lang As Variant
        For Each Lang In Languages
            If UCase(Lang(0)) = UCase(Language) Then
                Supported = True
                Exit For
            End If
        Next
        If Not Supported Then Err.Raise 1, , "Language '" & Language & "' not supported"
    End If
    
    If CurrentLanguage = "" Or CurrentLanguage <> Language Or pIOcrEngine = 0 Then
        CreateOcrEngine Language
    End If
    
    If pIOcrEngine = 0 Then Err.Raise 2, , "Unable to create OcrEngine"
    
    
    Dim pIRandomAccessStream As LongPtr: pIRandomAccessStream = CreateStreamOnFile(PathImage)
    If pIRandomAccessStream <> 0 Then
    
        Dim pIBitmapDecoder As LongPtr
        'pIBitmapDecoderStatics.CreateAsync
        Call vtblCall(pIBitmapDecoderStatics, 14 * PTR_SIZE, vbLong, CC_STDCALL, pIRandomAccessStream, VarPtr(pIBitmapDecoder))
        
        If pIBitmapDecoder <> 0 Then
            Dim pIOcrResult As LongPtr: pIOcrResult = GetOcrResult(pIBitmapDecoder)
            If UseLines Then
                'use IOCRLine
                Dim pFIVOcrLines As LongPtr
                'pIOcrResult.Lines
                Call vtblCall(pIOcrResult, 6 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(pFIVOcrLines))
                If pFIVOcrLines <> 0 Then
                    Dim NumberOfLines As Long
                    'pFIVOcrLines.GetSize
                    Call vtblCall(pFIVOcrLines, 7 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(NumberOfLines))
                    If NumberOfLines > 0 Then
                        Dim pIOCRLine As LongPtr
                        Dim hStringLine As LongPtr
                        Dim i As Long
                        For i = 0 To NumberOfLines - 1
                            'pFIVOcrLines.GetAt
                            Call vtblCall(pFIVOcrLines, 6 * PTR_SIZE, vbLong, CC_STDCALL, i, VarPtr(pIOCRLine))
                            If pIOCRLine <> 0 Then
                                'pIOCRLine.GetText
                                Call vtblCall(pIOCRLine, 7 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(hStringLine))
                                Result = Result & HStringToVBAString(hStringLine) & vbCrLf
                                WindowsDeleteString hStringLine
                                If ReturnWordsArray Then
                                    Dim pFIVOcrWords As LongPtr
                                    'pIOCRLine.GetWords
                                    Call vtblCall(pIOCRLine, 6 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(pFIVOcrWords))
                                    If pFIVOcrWords <> 0 Then
                                        Dim NumberOfWords As Long
                                        'pFIVOcrWords.GetSize
                                        Call vtblCall(pFIVOcrWords, 7 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(NumberOfWords))
                                        Dim pIOCRWord As LongPtr
                                        Dim hStringWord As LongPtr
                                        Dim x As Long
                                        If NumberOfWords > 0 Then
                                            ReDim Preserve ResultArray(UBound(ResultArray) + NumberOfWords)
                                            For x = 0 To NumberOfWords - 1
                                                'pFIVOcrWords.GetAt
                                                Call vtblCall(pFIVOcrWords, 6 * PTR_SIZE, vbLong, CC_STDCALL, x, VarPtr(pIOCRWord))
                                                If pIOCRWord <> 0 Then
                                                    'pFIVOcrWords.GetTect
                                                    Call vtblCall(pIOCRWord, 7 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(hStringWord))
                                                    Dim pRect As RECT
                                                    Call vtblCall(pIOCRWord, 6 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(pRect))
                                                    Dim WordInfo(4) As Variant
                                                    
                                                    WordInfo(0) = HStringToVBAString(hStringWord)
                                                    WordInfo(1) = pRect.x
                                                    WordInfo(2) = pRect.Y
                                                    WordInfo(3) = pRect.Width
                                                    WordInfo(4) = pRect.Height
                                                    
                                                    ResultArray(x + UBound(ResultArray) - NumberOfWords + 1) = WordInfo
                                                    WindowsDeleteString hStringWord
                                                End If
                                            Next
                                        End If
                                    End If
                                End If
                            End If
                        Next
                    End If
                End If
            Else
                'use whole text
                Dim hStringResult As LongPtr
                'pIOcrResult.Text
                Call vtblCall(pIOcrResult, 8 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(hStringResult))
                Result = HStringToVBAString(hStringResult)
                WindowsDeleteString hStringResult
            End If
        End If
    End If
    ResultArray(0) = Result
    ImageToText = ResultArray
End Function

Private Function GetOcrResult(ByRef pIBitmapDecoder As LongPtr) As LongPtr
    If WaitForAsyncInterface(pIBitmapDecoder) Then
        Dim pIBitmapFrame As LongPtr
        pIBitmapFrame = GetBitmapFrame(pIBitmapDecoder)
        If pIBitmapFrame <> 0 Then
            Dim Width As Long: Width = GetBitmapWidth(pIBitmapFrame)
            Dim Height As Long: Height = GetBitmapHeight(pIBitmapFrame)
            Dim MaxImageDimension As Long: Call vtblCall(pIOcrEngineStatics, 6 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(MaxImageDimension))
            If MaxImageDimension > Width And MaxImageDimension > Height Then
                Dim pIBitmapFrameWithSoftwareBitmap As LongPtr: pIBitmapFrameWithSoftwareBitmap = GetBitmapFrameWithSoftwareBitmap(pIBitmapDecoder)
                If pIBitmapFrameWithSoftwareBitmap <> 0 Then
                    Dim pISoftwareBitmap As LongPtr
                    'pIBitmapFrameWithSoftwareBitmap.GetSoftwareBitmapAsync
                    Call vtblCall(pIBitmapFrameWithSoftwareBitmap, 6 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(pISoftwareBitmap))
                    If pISoftwareBitmap <> 0 Then
                        If WaitForAsyncInterface(pISoftwareBitmap) Then
                            Dim pIOcrResult  As LongPtr
                            'pIOcrEngine.RecognizeAsync
                            Call vtblCall(pIOcrEngine, 6 * PTR_SIZE, vbLong, CC_STDCALL, pISoftwareBitmap, VarPtr(pIOcrResult))
                            If WaitForAsyncInterface(pIOcrResult) Then
                                GetOcrResult = pIOcrResult
                            End If
                        End If
                    End If
                End If
            End If
        End If
    End If
End Function

Public Function GetSupportedLanguages() As Collection

    If Not IsInitialized Then
        Initialize
    End If

    If Not Languages Is Nothing Then
        Set Languages = Nothing
    End If
    
    Set Languages = New Collection
   
    
    Dim pFIVLanguages As LongPtr                 'pointer to IID___FIVectorView_1_HSTRING
    'pIGlobalizationPreferencesStatics.GetLanguages
    Call vtblCall(pIGlobalizationPreferencesStatics, 9 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(pFIVLanguages))
    
    'MsgBox pFIVLanguages
    Dim iCountLenguages As Long
    'pFIVLanguages.GetSize
    Call vtblCall(pFIVLanguages, 7 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(iCountLenguages))
    
    Dim Language As String
    If iCountLenguages Then
        Dim i As Long
        Dim hStringLanguage As LongPtr
        Dim pILanguage As LongPtr
        
        For i = 0 To iCountLenguages - 1
        
            'pFIVLanguages.GetAt
            Call vtblCall(pFIVLanguages, 6 * PTR_SIZE, vbLong, CC_STDCALL, i, VarPtr(hStringLanguage))
            Language = HStringToVBAString(hStringLanguage)
            If Language <> "" Then
               
                'pILanguageFactory.CreateLanguage
                Call vtblCall(pILanguageFactory, 6 * PTR_SIZE, vbLong, CC_STDCALL, hStringLanguage, VarPtr(pILanguage))
                If pILanguage <> 0 Then
                    Dim hStringLanguageTag As LongPtr
                    Dim hStringLanguageDisplayName As LongPtr
                    Dim LanguageTag As String
                    Dim LanguageDisplayName As String
                    
                    'pILanguage.GetLanguageTag
                    Call vtblCall(pILanguage, 6 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(hStringLanguageTag))
                    'pILanguage.GetDisplayName
                    Call vtblCall(pILanguage, 7 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(hStringLanguageDisplayName))
                
                    LanguageTag = HStringToVBAString(hStringLanguageTag)
                    LanguageDisplayName = HStringToVBAString(hStringLanguageDisplayName)
                    
                    Dim IsLanguageSupported As Boolean
                    'pIOcrEngineStatics.IsLanguageSupported
                    Call vtblCall(pIOcrEngineStatics, 8 * PTR_SIZE, vbLong, CC_STDCALL, pILanguage, VarPtr(IsLanguageSupported))
                    
                    If IsLanguageSupported Then
                        Dim LangInfo(0 To 1) As String
                        LangInfo(0) = LanguageTag
                        LangInfo(1) = LanguageDisplayName
                        Languages.Add LangInfo
                    End If
                    
                    WindowsDeleteString hStringLanguageTag
                    WindowsDeleteString hStringLanguageDisplayName
                End If
                
                WindowsDeleteString hStringLanguage
            End If
        Next
    
    End If
    
    Set GetSupportedLanguages = Languages

End Function

Private Sub CreateOcrEngine(ByVal Language As String)
    Dim pILanguage As LongPtr
    Dim hStringLanguage As LongPtr
    Call WindowsCreateString(StrPtr(Language), Len(Language), hStringLanguage)
    'pILanguageFactory.CreateLanguage
    Call vtblCall(pILanguageFactory, 6 * PTR_SIZE, vbLong, CC_STDCALL, hStringLanguage, VarPtr(pILanguage))
    If pILanguage <> 0 Then
        'pIOcrEngineStatics.TryCreateFromLanguage
        Call vtblCall(pIOcrEngineStatics, 9 * PTR_SIZE, vbLong, CC_STDCALL, pILanguage, VarPtr(pIOcrEngine))
    End If
End Sub

Private Function GetBitmapWidth(ByRef pIBitmapFrame As LongPtr) As Long
    'pIBitmapFrame.PixelWidth
    Call vtblCall(pIBitmapFrame, 12 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(GetBitmapWidth))
End Function

Private Function GetBitmapHeight(ByRef pIBitmapFrame As LongPtr) As Long
    'pIBitmapFrame.PixelHeight
    Call vtblCall(pIBitmapFrame, 13 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(GetBitmapHeight))
End Function

Private Function GetBitmapFrameWithSoftwareBitmap(ByRef pIBitmapDecoder As LongPtr) As LongPtr
    Dim pGUID As GUID
    Call CLSIDFromString(StrPtr("{FE287C9A-420C-4963-87AD-691436E08383}"), pGUID) 'IID_IBitmapFrameWithSoftwareBitmap
    'pIBitmapDecoder.QueryInterface
    Call vtblCall(pIBitmapDecoder, 0 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(pGUID), VarPtr(GetBitmapFrameWithSoftwareBitmap))
End Function

Private Function GetBitmapFrame(ByRef pIBitmapDecoder As LongPtr) As LongPtr
    Dim pGUID As GUID
    Call CLSIDFromString(StrPtr("{72A49A1C-8081-438D-91BC-94ECFC8185C6}"), pGUID) 'IID_IBitmapFrame
    'pIBitmapDecoder.QueryInterface
    Call vtblCall(pIBitmapDecoder, 0 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(pGUID), VarPtr(GetBitmapFrame))
End Function

Private Function WaitForAsyncInterface(ByRef pIBitmapDecoder As LongPtr) As Boolean
   
    Dim pIAsyncInfo As LongPtr
    Dim pGUID As GUID
    Call CLSIDFromString(StrPtr("{00000036-0000-0000-C000-000000000046}"), pGUID) 'IID_IAsyncInfo
    'pIBitmapDecoder.QueryInterface
    Call vtblCall(pIBitmapDecoder, 0 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(pGUID), VarPtr(pIAsyncInfo))
     
    Dim Status As Long
    Do
        DoEvents
        'IID_IAsyncInfo.GetStatus
        Call vtblCall(pIAsyncInfo, 7 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(Status))
    Loop Until Status <> 0
    
    Dim ErrorCode As Long
    'IID_IAsyncInfo.GetErrorCode
    Call vtblCall(pIAsyncInfo, 8 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(ErrorCode))
    
    Dim pINewBitmapDecoder As LongPtr
    'pIBitmapDecoder.GetResults
    Call vtblCall(pIBitmapDecoder, 8 * PTR_SIZE, vbLong, CC_STDCALL, VarPtr(pINewBitmapDecoder))
    pIBitmapDecoder = pINewBitmapDecoder
    
    If pINewBitmapDecoder = 0 Then
        ErrorCode = 1
    End If

    WaitForAsyncInterface = (ErrorCode = 0) And Status = 1
  
End Function

Private Function CreateStreamOnFile(ByVal PathImage As String) As LongPtr
    Dim pIRandomAccessStream As LongPtr
    Dim pGUID As GUID
    Call CLSIDFromString(StrPtr("{905A0FE1-BC53-11DF-8C49-001E4FC686DA}"), pGUID) 'IID_IRandomAccessStream
    Call CreateRandomAccessStreamOnFile(StrPtr(PathImage), 0, pGUID, CreateStreamOnFile)
End Function

Private Function HStringToVBAString(ByVal hString As LongPtr) As String
    Dim pBuffer As LongPtr
    Dim iLength As Long
    Dim Buffer As String
    iLength = 0
    pBuffer = WindowsGetStringRawBuffer(hString, iLength)
    If pBuffer <> 0 And iLength <> 0 Then
        Buffer = String$(iLength, vbNull)
        CopyMemory ByVal StrPtr(Buffer), ByVal pBuffer, iLength * 2
    End If
    
    HStringToVBAString = Buffer
End Function


Private Function RoGetActivationIFactory(ByVal activatableClassId As String, ByVal sIID As String) As LongPtr
    Dim hString As LongPtr
    Call WindowsCreateString(StrPtr(activatableClassId), Len(activatableClassId), hString)
    If hString <> 0 Then
        Dim pGUID As GUID
        Dim pFactory As LongPtr
        Call CLSIDFromString(StrPtr(sIID), pGUID)
        Call RoGetActivationFactory(hString, pGUID, pFactory)
        If pFactory Then
            RoGetActivationIFactory = pFactory
            Exit Function
        End If
    End If
End Function


Private Function vtblCall( _
        ByVal InterfacePointer As LongPtr, _
        ByVal VTableOffset As Long, _
        ByVal FunctionReturnType As Long, _
        ByVal CallConvention As Long, _
        ParamArray FunctionParameters() As Variant _
        ) As Variant

    Dim vParamPtr() As LongPtr

    If InterfacePointer = 0& Or VTableOffset < 0& Then Exit Function
    If Not (FunctionReturnType And &HFFFF0000) = 0& Then Exit Function

    Dim pIndex As Long, pCount As Long
    Dim vParamType() As Integer
    Dim vRtn As Variant, vParams() As Variant

    vParams() = FunctionParameters()
    pCount = Abs(UBound(vParams) - LBound(vParams) + 1&)
    If pCount = 0& Then
        ReDim vParamPtr(0 To 0)
        ReDim vParamType(0 To 0)
    Else
        ReDim vParamPtr(0 To pCount - 1&)
        ReDim vParamType(0 To pCount - 1&)
        For pIndex = 0& To pCount - 1&
            vParamPtr(pIndex) = VarPtr(vParams(pIndex))
            vParamType(pIndex) = VarType(vParams(pIndex))
        Next
    End If

    pIndex = DispCallFunc(InterfacePointer, VTableOffset, CallConvention, FunctionReturnType, pCount, _
                          vParamType(0), vParamPtr(0), vRtn)
    If pIndex = 0& Then
        vtblCall = vRtn
    Else
        SetLastError pIndex
    End If

End Function







