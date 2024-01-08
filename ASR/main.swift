//
//  main.swift
//  ASR
//
//  Created by Soren Marcelino on 07/03/2023.
//


//MARK: ASR fonctionne en HTTP Server
import Foundation
import Speech
import Swifter

let server = HttpServer()

func transcribeAudio(request: HttpRequest) -> HttpResponse {
    let data = Data(request.body)
    let bodyString = String(data: data, encoding: .utf8)
    print(bodyString!)
    
    // Decode the base64-encoded audio data
    guard let audioData = Data(base64Encoded: bodyString!, options: .ignoreUnknownCharacters), let audioURL = writeAudioDataToFile(data: audioData) else {
        return .internalServerError
    }
    
    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    let request = SFSpeechURLRecognitionRequest(url: audioURL)
    var transcription: String?

    let semaphore = DispatchSemaphore(value: 0)
    recognizer?.recognitionTask(with: request) { result, error in
        var isFinal = false
        
        if let result = result {
            // Update the text view with the results
            isFinal = result.isFinal
            transcription = result.bestTranscription.formattedString
            print("Not final text : \(result.bestTranscription.formattedString)") // Print the results during listening
        }
        
        // Handle any errors that occurred during transcription
        if error != nil || isFinal {
            print("Transcription Finale: \(transcription ?? "")")
            semaphore.signal()
        }
    }
    
    _ = semaphore.wait(timeout: .distantFuture)
    
    guard let transcribedText = transcription else {
        return .internalServerError
    }
    
    return .ok(.text(transcription ?? ""))
}

server.POST["/transcribe"] = { request in
    return transcribeAudio(request: request)
}

func writeAudioDataToFile(data: Data) -> URL? {
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fileURL = directory.appendingPathComponent("audioData.mp3")

    do {
        try data.write(to: fileURL)
        return fileURL
    } catch {
        print("Error writing audio data to file: \(error)")
        return nil
    }
}

func encodeAudioTest(request: HttpRequest) -> HttpResponse {
    let audioURL = URL(fileURLWithPath: "/Users/sorenmarcelino/Documents/CareMateASR/ASR/LegacyTest.wav")
    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    guard let audioData = try? Data(contentsOf: audioURL) else {
        print("Could not read audio file")
        return .badRequest(.text("error : Could not read audio file"))
    }
    
    // Encode the audio file as base64
    let base64Audio = audioData.base64EncodedString()
    print("Audio : \(base64Audio)")
    
    return .ok(.text("OK"))
}

server.GET["/encode"] = { request in
    return encodeAudioTest(request: request)
}

do {
    try server.start(45876)
    print("Server is running on http://localhost:45876/")
    RunLoop.main.run()
} catch {
    print("Error starting server: \(error)")
}
