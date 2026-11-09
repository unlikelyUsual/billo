class L10n {
  const L10n(this.code);

  final String code;
  bool get isThai => code == 'th';

  String get demoBanner =>
      isThai ? 'เดโม · ไม่มีการเคลื่อนเงินจริง' : 'DEMO · No real money moves';
  String get household =>
      isThai ? 'ครัวเรือนเดโม · กรุงเทพ' : 'Demo household · Bangkok';
  String get openBalance => isThai ? 'ยอดที่ต้องชำระ' : 'Open balance';
  String get minimum => isThai ? 'ขั้นต่ำ' : 'Minimum';
  String get dueSoon => isThai ? 'ใกล้ครบกำหนด' : 'Due soon';
  String get pending => isThai ? 'รอผล' : 'Pending';
  String get needsReview => isThai ? 'ต้องตรวจ' : 'Needs review';
  String get bills => isThai ? 'บิล' : 'Bills';
  String get home => isThai ? 'หน้าหลัก' : 'Home';
  String get cards => isThai ? 'บัตร' : 'Cards';
  String get activity => isThai ? 'รายการ' : 'Activity';
  String get selectPayable => isThai ? 'เลือกที่จ่ายได้' : 'Select payable';
  String get clear => isThai ? 'ล้าง' : 'Clear';
  String get reviewPayment => isThai ? 'ตรวจรายการจ่าย' : 'Review payment';
  String get simulate => isThai ? 'จำลองการจ่าย' : 'Simulate payment';
  String get import => isThai ? 'นำเข้า' : 'Import';
  String get about => isThai ? 'เกี่ยวกับเดโม' : 'About this demo';
  String get confirmed => isThai ? 'ยืนยันแล้ว' : 'Confirmed';
  String get settled => isThai ? 'ตัดในเดโมแล้ว' : 'Settled in demo';
  String get failed => isThai ? 'ไม่สำเร็จ' : 'Declined';
  String get open => isThai ? 'เปิดอยู่' : 'Open';
  String get fullAmount => isThai ? 'ยอดเต็ม' : 'Full amount';
  String get dueDate => isThai ? 'วันครบกำหนด' : 'Due date';
  String get statementDate => isThai ? 'วันตัดรอบ' : 'Statement date';
  String get save => isThai ? 'บันทึกการแก้' : 'Save corrections';
  String get confirm => isThai ? 'ยืนยันใบแจ้งยอด' : 'Confirm statement';
  String get tryAgain => isThai ? 'ลองอีกครั้ง' : 'Try again';
  String get emptyBills => isThai ? 'ไม่มีบิลค้าง' : 'No open bills';
  String get emptyActivity => isThai ? 'ยังไม่มีรายการจ่าย' : 'No payments yet';
  String get loading =>
      isThai ? 'กำลังเปิดสมุดเดโม' : 'Opening the demo ledger';
  String get apiDown => isThai
      ? 'ยังเชื่อม API เดโมไม่ได้ เปิดเซิร์ฟเวอร์แล้วลองอีกครั้ง'
      : "Can't reach the demo API. Start it, then try again.";
  String get scripted => isThai
      ? 'ผลจำลองตามผู้ออกบัตร ไม่ได้ส่งให้ธนาคาร'
      : 'Scripted per issuer. Nothing is sent to a bank.';
  String get payFull => isThai
      ? 'เดโมนี้จ่ายยอดเต็มของแต่ละบิล'
      : 'This demo pays the full amount of each selected bill.';
  String get noRetry => isThai
      ? 'บิลโลจะไม่จ่ายรายการนี้ซ้ำ'
      : 'Billo will not retry this payment.';
  String get uncertain => isThai
      ? 'ผลยังไม่ชัด อย่าเพิ่งจ่ายบิลนี้อีก ต้องตรวจกับผู้ออกบัตรก่อน'
      : 'Outcome uncertain. Do not pay this bill again until someone checks with the issuer.';
  String get declined => isThai
      ? 'ผู้ออกบัตรในเดโมปฏิเสธ ยังไม่มีการจ่าย เริ่มรายการใหม่ได้'
      : 'The demo issuer declined this bill. No money moved. You can start a new payment.';
  String get settledNote => isThai
      ? 'ตัดยอดในสมุดเดโมเท่านั้น'
      : 'Marked settled in the demo ledger only.';
  String get importHelp => isThai
      ? 'ตัวอย่างเป็นข้อมูลสมมติ ตรวจยอดก่อนยืนยัน'
      : 'Samples are synthetic. Review the amounts before you confirm.';
  String get pdfHelp => isThai
      ? 'อ่านได้เฉพาะ PDF ตัวอย่างที่มีเครื่องหมาย ไฟล์อื่นจะหยุดและไม่เดายอด'
      : 'Only a marked sample PDF can be read. Anything else stops, and amounts are not guessed.';
  String get extractSample =>
      isThai ? 'อ่าน PDF ตัวอย่าง' : 'Extract sample PDF';
  String get extractOther => isThai ? 'ลอง PDF ทั่วไป' : 'Try an ordinary PDF';
  String get amountsNotGuessed =>
      isThai ? 'ระบบไม่ได้เดายอดเงิน' : 'Amounts were not guessed.';
  String get extractionUnavailable =>
      isThai ? 'ยังอ่าน PDF นี้ไม่ได้' : 'Extraction unavailable';
  String get duplicate => isThai ? 'มีบิลนี้อยู่แล้ว' : 'Already in the ledger';
  String get reset => isThai ? 'ล้างข้อมูลเดโม' : 'Reset demo data';
  String get language => isThai ? 'ภาษา' : 'Language';
  String get ending => isThai ? 'ลงท้าย' : 'ending';
  String get yourCards => isThai ? 'บัตรของคุณ' : 'Your cards';
  String get statement => isThai ? 'ใบแจ้งยอด' : 'Statement';
  String get simulator => isThai ? 'ผลจำลอง' : 'Scripted outcomes';
  String get result => isThai ? 'ผลการจำลอง' : 'Simulated result';
  String get networkDuringPay => isThai
      ? 'ไม่ทราบผลจากเซิร์ฟเวอร์ กดอีกครั้งจะใช้รหัสเดิม เพื่อไม่ให้ตัดซ้ำ'
      : 'No response from the server. The next tap reuses the same idempotency key.';
  String billsCount(int count) => isThai ? '$count บิล' : '$count bills';

  String dueLabel(int days) {
    if (days == 0) return isThai ? 'ครบกำหนดวันนี้' : 'Due today';
    if (days == 1) return isThai ? 'ครบกำหนดพรุ่งนี้' : 'Due tomorrow';
    if (days > 1) return isThai ? 'อีก $days วัน' : 'Due in $days days';
    final overdue = -days;
    return isThai ? 'เลยมา $overdue วัน' : '$overdue days overdue';
  }

  String reviewLabel(String state) {
    switch (state) {
      case 'needs_review':
        return needsReview;
      case 'confirmed':
        return confirmed;
      default:
        return state;
    }
  }

  String settlementLabel(String state) {
    switch (state) {
      case 'settled':
        return settled;
      case 'payment_pending':
        return pending;
      case 'payment_failed':
        return failed;
      default:
        return open;
    }
  }

  String outcomeNote(String status) {
    switch (status) {
      case 'pending':
        return uncertain;
      case 'failed':
        return declined;
      default:
        return settledNote;
    }
  }

  String get gmailTitle =>
      isThai ? 'Gmail ยังไม่เชื่อม' : 'Gmail is not connected';
  String get gmailBody => isThai
      ? 'gmail.readonly เป็น scope แบบจำกัด ต้องผ่านการตรวจสอบของ Google และการประเมินความปลอดภัยก่อนใช้งานจริง แอปที่ยังไม่ผ่านจะใช้ได้เฉพาะผู้ใช้ทดสอบ อย่าขอ gmail.modify เดโมนี้ไม่เชื่อมกล่องจดหมาย'
      : 'gmail.readonly is a restricted scope. Production needs Google verification and a security assessment. Unverified apps stay capped to test users. Do not request gmail.modify. This demo connects no mailbox.';
  String get billTitle =>
      isThai ? 'ยังไม่มีการจ่ายบิลจริง' : 'No real bill payment';
  String get billBody => isThai
      ? 'PromptPay ทั่วไปไม่ได้รับประกันว่าบิลบัตรเครดิตจะถูกตัด ต้องใช้พันธมิตรที่ได้รับอนุญาต พร้อมรหัสผู้รับเงินหรือ comp code และต้องกระทบยอด ถ้าผลยังไม่แน่นอน ห้ามจ่ายซ้ำ'
      : 'A generic PromptPay transfer does not guarantee a credit-card bill is settled. Production needs a licensed partner, the issuer biller or comp code, and reconciliation. An uncertain result must not be retried.';
  String get privacyTitle =>
      isThai ? 'ความเป็นส่วนตัว ขั้นต่อไป' : 'Privacy, next';
  String get privacyBody => isThai
      ? 'ก่อนเก็บข้อมูลจริง ต้องมีคำยินยอม ระยะเวลาเก็บ และวิธียกเลิกหรือลบใบแจ้งยอด ตาม PDPA แอปนี้ไม่เก็บเลขบัตรเต็มหรือ CVV'
      : 'Before real data: consent, a retention window, and a way to delete statements, under Thailand PDPA. This demo stores no full card number and no CVV.';
}
