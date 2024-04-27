import UIKit
import Speech

class FirstQuestionViewController: UIViewController,SFSpeechRecognitionTaskDelegate, SFSpeechRecognizerDelegate {
    
    @IBOutlet weak var inputVoiceButton: UIButton!
    @IBOutlet weak var voiceTextView: UITextView!
    
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    var recognitionTask: SFSpeechRecognitionTask?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var audioEngine =  AVAudioEngine()
    var lastVoiceText = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        inputVoiceButton.isEnabled = false
        voiceTextView.text = ""
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        speechRecognizer.delegate = self
        
        //音声入力に関する許可の確認
        SFSpeechRecognizer.requestAuthorization { (status) in
            OperationQueue.main.addOperation {
                switch status {
                case .authorized://許可
                    self.inputVoiceButton.isEnabled = true
                default://許可以外
                    self.inputVoiceButton.isEnabled = false
                    self.inputVoiceButton.setTitle("録音許可なし", for: .disabled)
                    self.inputVoiceButton.backgroundColor = .lightGray
                }
            }
        }
    }
    
    @IBAction func inputVoiceButtonTapped(_ sender: Any) {
        
        if audioEngine.isRunning == true{
            //音声エンジン動作中なら停止し、音声テキストを表示
            audioEngine.stop()
            recognitionRequest?.endAudio()
            inputVoiceButton.setTitle("音声操作", for: [])
            inputVoiceButton.backgroundColor = .green
        }else{
            //音声エンジンが停止中なら録音スタート
            try! Recording()
            inputVoiceButton.setTitle("音声認識を完了する", for: [])
            inputVoiceButton.backgroundColor = UIColor.red
        }
    }
    
    //「健康です」を押した際の処理
    @IBAction func GoodButtonTapped(_ sender: Any) {
        GoodButtonAction()
    }
    
    //「具合が悪い」を押した際の処理
    @IBAction func BadButtonTapped(_ sender: Any) {
        BadButtonAction()
    }
    
    //「健康です」ボタンの次の画面へ遷移
    func GoodButtonAction(){
        let storyboard:UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let nextVC = storyboard.instantiateViewController(identifier: "ResultViewController") as! ResultViewController
        self.navigationController?.pushViewController(nextVC, animated: true)
    }
    
    //「具合が悪い」ボタンの次の画面へ遷移
    func BadButtonAction(){
        let storyboard:UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let nextVC = storyboard.instantiateViewController(identifier: "SecondQuestionViewController") as! SecondQuestionViewController
        self.navigationController?.pushViewController(nextVC, animated: true)
    }
    
    //文字化した音声がどちらの選択肢に似ている文字列か判定し画面遷移を自動で行う
    func checkVoiceText(){
        switch determineSimilarity(self.lastVoiceText, "健康です", "具合が悪い"){
        case 1:
            GoodButtonAction()
            break
        case 2:
            BadButtonAction()
            break
        default:break
        }
    }
    
    //Levenshtein距離を算出(2つの文字列がどれだけ異なるかを示す指標であり、この距離が小さいほど文字列同士の類似度が高いことを意味している)
    func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let len1 = s1.count
        let len2 = s2.count
        
        var dist = [[Int]](repeating: [Int](repeating: 0, count: len2 + 1), count: len1 + 1)
        
        for i in 0...len1 {
            dist[i][0] = i
        }
        
        for j in 0...len2 {
            dist[0][j] = j
        }
        
        for i in 1...len1 {
            for j in 1...len2 {
                let cost = (s1[s1.index(s1.startIndex, offsetBy: i - 1)] == s2[s2.index(s2.startIndex, offsetBy: j - 1)]) ? 0 : 1
                dist[i][j] = Swift.min(Swift.min(dist[i - 1][j] + 1, dist[i][j - 1] + 1), dist[i - 1][j - 1] + cost)
            }
        }
        return dist[len1][len2]
    }
    
    //levenshteinDistance関数を呼ぶことで、類似性の高い方の番号をint型で返す
    func determineSimilarity(_ input: String, _ text1: String, _ text2: String) -> Int {
        let distanceToText1 = levenshteinDistance(input, text1)
        let distanceToText2 = levenshteinDistance(input, text2)
        
        if distanceToText1 < distanceToText2 {
            return 1
        } else if distanceToText2 < distanceToText1 {
            return 2
        } else {
            return 3
        }
    }
    
    //音声文字起こし関数
    func Recording() throws {
        //音声認識タスクが実行中ならキャンセルしてリセット
        if let recognitionTask = self.recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        //音声認識リクエストを作成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {return}
        recognitionRequest.shouldReportPartialResults = false //(重要)初期値はtrue、falseにすると録音を止めた際に文字として出力される(仕様によって使い分け可能)
        
        //オーディオセッションの設定
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSession.Category.record)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        
        // マイクの設定
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { (buffer, time) in
            recognitionRequest.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        
        //音声認識タスクの実行
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            if let error = error {
                print("音声認識タスクエラー：\(error)")
            } else {
                DispatchQueue.main.async {
                    self.voiceTextView.text = result?.bestTranscription.formattedString
                    self.lastVoiceText = result?.bestTranscription.formattedString ?? ""
                    self.checkVoiceText()
                    self.audioEngine.inputNode.removeTap(onBus: 0) //エンジンを停止するときは、TapOnBus を削除する必要があるようだ
                }
            }
        })
    }
    
    
}
    
    
