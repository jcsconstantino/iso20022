<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<!-- Optional. "yes" specifies that the XML declaration (<?xml...?>) should be omitted in the output. "no" specifies that the XML declaration should be included in the output. The default is "no"  -->
	<xsl:output omit-xml-declaration="no"/>
	<xsl:output method="xml"/>
	<!-- Create one index for the instruction grouping. This index will be used for SEPA instructions to allow grouping by the instruction identifier -->
	<xsl:key name="index-GroupID" match="PaymentDetail" use="GroupingTag"/>
	<xsl:key name="index-PmtDocNumber" match="PayableDocuments" use="PmtDocumentNum"/>
	<!-- define variables -->
	<!-- variables to be used with the 'translate' function. This can be extended according to future needs. Limitations exist as the database is able to store multiple alphabets (cyrilic, greek, farsi, etc.) and a conversion is not always possible. It may be required in the future to translate a single character with a string, for instance, the german umlaute and eszett 'ä', 'ö', 'ü', ß  into 'ae', 'oe', 'ue', 'ss'. If proven to be required then multiple instances of translate must be used -->
	<!-- The pair lowercase/uppercase is used to capitalize the string in basic + extended latin -->
	<xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyzàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿžšœ'"/>
	<xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞŸŽŠŒ'"/>
	<!-- The pair extlatin/basiclatin is used to convert extended latin into basic latin -->
	<xsl:variable name="extlatin" select="'ĀāĂăĄąĆćĈĉĊċČčĎďĐđĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħĨĩĪīĬĭĮįİıĲĳĴĵĶķĸĹĺĻļĽľĿŀŁłŃńŅņŇňŉŊŋŌōŎŏŐőŒœŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŦŧŨũŪūŬŭŮůŰűŲųŴŵŶŷŸŹźŻżŽžſàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿžšœÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞŸŽŠŒ'"/>
	<xsl:variable name="basiclatin" select="'AaAaAaCcCcCcCcDdEeEeEeEeEeEeGgGgGgGgHhHhIiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnnNnOoOoOoOoRrRrRrSsSsSsSsTtTtTtUuUuUuUuUuUuWwYyYZzZzZzSaaaaaaaceeeeiiiidnoooooouuuuydyzsoAAAAAAACEEEEIIIIDNOOOOODUUUUYDYZSO'"/>
	<!-- The pair jpfwkatakana/jphwkatakana is used for two purposes: 1. to convert any full-width katakana into half-width; 2. Remove unwanted characters such as '/-?:().,+=!%*@#$;'  -->
	<xsl:variable name="jpfwkatakana" select="'。「」、・ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン゛゜/-?:().,+=!%*@#$;'"/>
	<xsl:variable name="jphwkatakana" select="'｡｢｣､･ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝﾞﾟ'"/>
	<!-- Set the context to the header  -->
	<xsl:template match="PaymentBatch">
		<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.03" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<CstmrCdtTrfInitn>
				<!-- HEADER ELEMENTS -->
				<GrpHdr>
					<MsgId>
						<xsl:value-of select="PmtBatchDetails/PmtBatchRef"/>
					</MsgId>
					<CreDtTm>
						<xsl:value-of select="PmtBatchDetails/PmtBatchCreationDate"/>
					</CreDtTm>
					<NbOfTxs>
						<xsl:value-of select="PmtBatchDetails/BatchTotals/NumPayments"/>
					</NbOfTxs>
					<CtrlSum>
						<xsl:value-of select="format-number(PmtBatchDetails/BatchTotals/TotalAmount,'#.00')"/>
					</CtrlSum>
					<!-- The InitgPrty tag is common for both SEPA and Global, and there are slightly different requirements on the allowed character sets. The safe approach is to simplify the contents to basic latin and make it uppercase  -->
					<InitgPty>
						<Nm>
							<xsl:value-of select="translate(translate(GroupingElements/Payer/PayerName,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
						</Nm>
					</InitgPty>
				</GrpHdr>
				<!-- END OF HEADER ELEMENTS -->
				<!-- CONDITION - If we are paying SEPA, otherwise use the global template.
				The reason for this condition is the need to have a different grouping (all payments grouped under a single reference, for reconciliation purposes (all payments to be reconciled against a single bank statement line) -->
				<!-- A payment method tag exists both at the header level and for every individual payment. The one selected for the condition is the one at payment level. The reason for this is the fact that it is possible to have different types of payment method in the same instruction (at least theoretically), therefore the lowest level was chosen to be on the safe side. -->
				<!-- iteration: for each value of GroupingTag -->
				<xsl:for-each select="PaymentDetail[count(. | key('index-GroupID', GroupingTag)[1]) = 1]">
					<xsl:sort select="PaymentDetail/GroupingTag"/>
					<xsl:choose>
						<xsl:when test="(./PaymentMethod='SEPA')">
							<PmtInf>
								<PmtInfId>
									<xsl:value-of select="GroupingTag"/>
								</PmtInfId>
								<!-- hardcode 'TRF' for 'Credit Transfer' -->
								<PmtMtd>TRF</PmtMtd>
								<BtchBookg>
									<xsl:value-of select="BatchBooking"/>
								</BtchBookg>
								<NbOfTxs>
									<xsl:value-of select="TotalPayments"/>
								</NbOfTxs>
								<CtrlSum>
									<xsl:value-of select="format-number(TotalAmount,'#.00')"/>
								</CtrlSum>
								<PmtTpInf>
									<SvcLvl>
										<Cd>
											<xsl:value-of select="PaymentMethod"/>
										</Cd>
									</SvcLvl>
								</PmtTpInf>
								<ReqdExctnDt>
									<xsl:value-of select="PaymentDate"/>
								</ReqdExctnDt>
								<Dbtr>
									<Nm>
										<xsl:value-of select="translate(translate(/PaymentBatch/GroupingElements/Payer/PayerName,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
									</Nm>
									<PstlAdr>
										<!-- Condition: if address line 2 exists, then concatenate address lines 1 and 2, otherwise populate address line 1 only. It is assumed that Address Line 1 always exists -->
										<xsl:choose>
											<xsl:when test="not(//Payer/Address/AddLine2='')">
												<StrtNm>
													<xsl:value-of select="translate(substring(concat(//Payer/Address/AddLine1,', ',//Payer/Address/AddLine2),1,70),$extlatin,$basiclatin)"/>
												</StrtNm>
											</xsl:when>
											<xsl:otherwise>
												<StrtNm>
													<xsl:value-of select="translate(substring(//Payer/Address/AddLine1,1,70),$extlatin,$basiclatin)"/>
												</StrtNm>
											</xsl:otherwise>
										</xsl:choose>
										<!-- only create the following tags if values to populate them exist -->
										<xsl:if test="not(//Payer/Address/PostalCode='')">
											<PstCd>
												<xsl:value-of select="translate(//Payer/Address/PostalCode,$extlatin,$basiclatin)"/>
											</PstCd>
										</xsl:if>
										<xsl:if test="not(//Payer/Address/City='')">
											<TwnNm>
												<xsl:value-of select="translate(//Payer/Address/City,$extlatin,$basiclatin)"/>
											</TwnNm>
										</xsl:if>
										<xsl:if test="not(//Payer/Address/Country2Digit='')">
											<Ctry>
												<xsl:value-of select="translate(//Payer/Address/Country2Digit,$extlatin,$basiclatin)"/>
											</Ctry>
										</xsl:if>
									</PstlAdr>
								</Dbtr>
								<DbtrAcct>
									<Id>
										<!-- For SEPA an IBAN is always necessary (and assumed to exist) -->
										<IBAN>
											<xsl:value-of select="//IntBankAccount/IBAN"/>
										</IBAN>
									</Id>
									<Ccy>
										<xsl:value-of select="//IntBankAccount/Currency"/>
									</Ccy>
								</DbtrAcct>
								<DbtrAgt>
									<FinInstnId>
										<!-- The internal bank account BIC is expected to exist -->
										<BIC>
											<xsl:value-of select="//IntBankAccount/BICSWIFT"/>
										</BIC>
										<PstlAdr>
											<!-- Condition: if address line 2 exists, then concatenate address lines 1 and 2, otherwise populate address line 1 only. It is assumed that Address Line 1 always exists -->
											<xsl:choose>
												<xsl:when test="not(//IntBankAccount/BankAddress/AddLine2='')">
													<StrtNm>
														<xsl:value-of select="translate(substring(concat(//IntBankAccount/BankAddress/AddLine1,', ',//IntBankAccount/BankAddress/AddLine2),1,70),$extlatin,$basiclatin)"/>
													</StrtNm>
												</xsl:when>
												<xsl:otherwise>
													<StrtNm>
														<xsl:value-of select="translate(substring(//IntBankAccount/BankAddress/AddLine1,1,70),$extlatin,$basiclatin)"/>
													</StrtNm>
												</xsl:otherwise>
											</xsl:choose>
											<!-- only create the following tags if values to populate them exist -->
											<xsl:if test="not(//IntBankAccount/BankAddress/PostalCode='')">
												<PstCd>
													<xsl:value-of select="translate(//IntBankAccount/BankAddress/PostalCode,$extlatin,$basiclatin)"/>
												</PstCd>
											</xsl:if>
											<xsl:if test="not(//IntBankAccount/BankAddress/City='')">
												<TwnNm>
													<xsl:value-of select="translate(//IntBankAccount/BankAddress/City,$extlatin,$basiclatin)"/>
												</TwnNm>
											</xsl:if>
											<xsl:if test="not(//IntBankAccount/BankAddress/Country2Digit='')">
												<Ctry>
													<xsl:value-of select="//IntBankAccount/BankAddress/Country2Digit"/>
												</Ctry>
											</xsl:if>
										</PstlAdr>
									</FinInstnId>
								</DbtrAgt>
								<!-- Iteration: loop through all grouping tags -->
								<xsl:for-each select="key('index-GroupID', ./GroupingTag)">
									<xsl:sort select="./GroupingTag"/>
									<CdtTrfTxInf>
										<PmtId>
											<InstrId>
												<xsl:value-of select="./PmtDocumentNum"/>
											</InstrId>
											<EndToEndId>
												<xsl:value-of select="./PmtDocumentNum"/>
											</EndToEndId>
										</PmtId>
										<Amt>
											<InstdAmt>
												<xsl:attribute name="Ccy">
													<xsl:value-of select="./PaymentAmount/Currency"/>
												</xsl:attribute>
												<xsl:value-of select="format-number(./PaymentAmount/Value,'#.00')"/>
											</InstdAmt>
										</Amt>
										<!-- For SEPA, the BIC/SWIFT may not be required. The condition below will create and populate the tag if a BIC/SWIFT is provided -->
										<xsl:if test="not(./PayeeBankAccount/BICSWIFT='')">
											<CdtrAgt>
												<FinInstnId>
													<BIC>
														<xsl:value-of select="./PayeeBankAccount/BICSWIFT"/>
													</BIC>
												</FinInstnId>
											</CdtrAgt>
										</xsl:if>
										<Cdtr>
											<!-- capitalize and substring to a maximum of 140 characters. Call the lowercase/uppercase variables
												 allow extended latin to be part of the bank account name -->
											<Nm>
												<xsl:value-of select="translate(substring(./PayeeBankAccount/BankAccountName,1,140),$lowercase,$uppercase)"/>
											</Nm>
											<!-- NOTE: payee address is not mandatory for SEPA, we keep it anyway but it can easily be removed -->
											<PstlAdr>
												<!-- Condition: if address line 2 exists, then concatenate address lines 1 and 2, otherwise populate address line 1 only. It is assumed that Address Line 1 always exists -->
												<xsl:choose>
													<xsl:when test="not(./Payee/Address/AddLine2='')">
														<StrtNm>
															<xsl:value-of select="translate(substring(concat(./Payee/Address/AddLine1,', ',./Payee/PayeeAddress/AddLine2),1,70),$extlatin,$basiclatin)"/>
														</StrtNm>
													</xsl:when>
													<xsl:otherwise>
														<StrtNm>
															<xsl:value-of select="translate(substring(./Payee/Address/AddLine1,1,70),$extlatin,$basiclatin)"/>
														</StrtNm>
													</xsl:otherwise>
												</xsl:choose>
												<!-- only create the following tags if values to populate them exist -->
												<xsl:if test="not(./Payee/Address/PostalCode='')">
													<PstCd>
														<xsl:value-of select="translate(./Payee/Address/PostalCode,$extlatin,$basiclatin)"/>
													</PstCd>
												</xsl:if>
												<xsl:if test="not(./Payee/Address/City='')">
													<TwnNm>
														<xsl:value-of select="translate(./Payee/Address/City,$extlatin,$basiclatin)"/>
													</TwnNm>
												</xsl:if>
												<xsl:if test="not(./Payee/Address/Country2Digit='')">
													<Ctry>
														<xsl:value-of select="./Payee/Address/Country2Digit"/>
													</Ctry>
												</xsl:if>
											</PstlAdr>
										</Cdtr>
										<CdtrAcct>
											<Id>
												<!-- For SEPA, IBAN is expected to exist -->
												<IBAN>
													<xsl:value-of select="./PayeeBankAccount/IBAN"/>
												</IBAN>
											</Id>
										</CdtrAcct>
										<RmtInf>
											<!-- Condition: the tag 'StructuredRem' triggers the use of a structured remittance details (Y) or unstructured (N). If a Structured remittance is used, display the Ustrd tag as well for all banks and profiles.
											Multiple instances of Ustrd can be created, Bank A only allows one instance and an exception must be added for this reason. This may cause problems whenever many documents are paid simultaneously as we may not have much room to state the purpose of payment.
											The rule is:
											- Loop all documents paid and concatenate documentnumber;documentamount;paymentamount;purposeofpayment|
											- If the transaction is a credit memo (not CINV), display the amounts as negative
											- if no purpose of payment is provided, default 'Payment for Goods and Services'
											- substring to 140 characters (always)
											Use the variable remittancemsg to store the entire string, in order to substring it to 140 characters after the entire tag has been created. -->
											<xsl:if test="(./StructuredRem='N')">
												<xsl:variable name="remittancemsg">
													<xsl:for-each select="./PayableDocuments">
														<xsl:value-of select="./DocNumber"/>
														<xsl:choose>
															<xsl:when test="./DocType='CINV'">
																<xsl:value-of select="concat(';',./DocAmount/Value,';',./PaymentAmount/Value,';')"/>
															</xsl:when>
															<xsl:otherwise>
																<xsl:value-of select="concat(';-',./DocAmount/Value,';-',./PaymentAmount/Value,';')"/>
															</xsl:otherwise>
														</xsl:choose>
														<xsl:if test="not(./PurpPayment/DisplayValue='')">
															<xsl:value-of select="concat(./PurpPayment/DisplayValue,'|')"/>
														</xsl:if>
														<xsl:if test="./PurpPayment/DisplayValue=''">Payment for Goods and Services|</xsl:if>
													</xsl:for-each>
												</xsl:variable>
												<xsl:if test="not(//IntBankAccount/BankName='Bank A')">
													<xsl:for-each select="./PayableDocuments">
														<xsl:variable name="remittancemsgmult">
															<xsl:value-of select="./DocNumber"/>
															<xsl:choose>
																<xsl:when test="./DocType='CINV'">
																	<xsl:value-of select="concat(';',./DocAmount/Value,';',./PaymentAmount/Value,';')"/>
																</xsl:when>
																<xsl:otherwise>
																	<xsl:value-of select="concat(';-',./DocAmount/Value,';-',./PaymentAmount/Value,';')"/>
																</xsl:otherwise>
															</xsl:choose>
															<xsl:if test="not(./PurpPayment/DisplayValue='')">
																<xsl:value-of select="concat(./PurpPayment/DisplayValue,'|')"/>
															</xsl:if>
															<xsl:if test="./PurpPayment/DisplayValue=''">Payment for Goods and Services|</xsl:if>
														</xsl:variable>
														<Ustrd>
															<xsl:value-of select="substring($remittancemsgmult,1,140)"/>
														</Ustrd>
													</xsl:for-each>
												</xsl:if>
												<xsl:if test="(//IntBankAccount/BankName='Bank A')">
													<Ustrd>
														<xsl:value-of select="substring($remittancemsg,1,140)"/>
													</Ustrd>
												</xsl:if>
											</xsl:if>
											<xsl:if test="(./StructuredRem='Y')">
												<!-- Multiple conditions: if the document type is CINV (invoice) then the tag RmtdAmt tag must be used to provide the amount and currency. If the document type is CREN (credit note) then the tag CdtNoteAmt must be used instead.
												If an ISO Credit Reference has been generated, then it will be used in the Ref tag (prefixed with 'RF' and 2 check digit and concatenated with the document number) and the Issr tag gets populated with 'ISO', otherwise only the Ref tag gets populated with the document number  -->
												<!-- loop through all the documents that make part of the payment
												Exceptions apply to Bank A which will only allow one instance of Ustrd -->
												<xsl:variable name="remittancemsg">
													<xsl:for-each select="./PayableDocuments">
														<xsl:value-of select="./DocNumber"/>
														<xsl:choose>
															<xsl:when test="./DocType='CINV'">
																<xsl:value-of select="concat(';',./DocAmount/Value,';',./PaymentAmount/Value,';')"/>
															</xsl:when>
															<xsl:otherwise>
																<xsl:value-of select="concat(';-',./DocAmount/Value,';-',./PaymentAmount/Value,';')"/>
															</xsl:otherwise>
														</xsl:choose>
														<xsl:if test="not(./PurpPayment/DisplayValue='')">
															<xsl:value-of select="concat(./PurpPayment/DisplayValue,'|')"/>
														</xsl:if>
														<xsl:if test="./PurpPayment/DisplayValue=''">Payment for Goods and Services|</xsl:if>
													</xsl:for-each>
												</xsl:variable>
												<xsl:if test="not(//IntBankAccount/BankName='Bank A')">
													<xsl:for-each select="./PayableDocuments">
														<xsl:variable name="remittancemsgmult">
															<xsl:value-of select="./DocNumber"/>
															<xsl:choose>
																<xsl:when test="./DocType='CINV'">
																	<xsl:value-of select="concat(';',./DocAmount/Value,';',./PaymentAmount/Value,';')"/>
																</xsl:when>
																<xsl:otherwise>
																	<xsl:value-of select="concat(';-',./DocAmount/Value,';-',./PaymentAmount/Value,';')"/>
																</xsl:otherwise>
															</xsl:choose>
															<xsl:if test="not(./PurpPayment/DisplayValue='')">
																<xsl:value-of select="concat(./PurpPayment/DisplayValue,'|')"/>
															</xsl:if>
															<xsl:if test="./PurpPayment/DisplayValue=''">Payment for Goods and Services|</xsl:if>
														</xsl:variable>
														<Ustrd>
															<xsl:value-of select="substring($remittancemsgmult,1,140)"/>
														</Ustrd>
													</xsl:for-each>
												</xsl:if>
												<xsl:if test="(//IntBankAccount/BankName='Bank A')">
													<Ustrd>
														<xsl:value-of select="substring($remittancemsg,1,140)"/>
													</Ustrd>
												</xsl:if>
												<xsl:for-each select="./PayableDocuments">
													<Strd>
														<RfrdDocInf>
															<Tp>
																<CdOrPrtry>
																	<Cd>
																		<xsl:value-of select="./DocType"/>
																	</Cd>
																</CdOrPrtry>
															</Tp>
														</RfrdDocInf>
														<RfrdDocAmt>
															<xsl:if test="./DocType='CINV'">
																<RmtdAmt>
																	<xsl:attribute name="Ccy">
																		<xsl:value-of select="./DocAmount/Currency"/>
																	</xsl:attribute>
																	<xsl:value-of select="format-number(./DocAmount/Value,'#.00')"/>
																</RmtdAmt>
															</xsl:if>
															<xsl:if test="./DocType='CREN'">
																<CdtNoteAmt>
																	<xsl:attribute name="Ccy">
																		<xsl:value-of select="./DocAmount/Currency"/>
																	</xsl:attribute>
																	<xsl:value-of select="format-number(./DocAmount/Value,'#.00')"/>
																</CdtNoteAmt>
															</xsl:if>
														</RfrdDocAmt>
														<CdtrRefInf>
															<Tp>
																<CdOrPrtry>
																	<!-- hardcoded SCOR -->
																	<Cd>SCOR</Cd>
																</CdOrPrtry>
																<xsl:if test="not(./CreditReference='')">
																	<Issr>ISO</Issr>
																</xsl:if>
															</Tp>
															<xsl:if test="not(./CreditReference='')">
																<Ref>
																	<xsl:value-of select="./CreditReference"/>
																</Ref>
															</xsl:if>
															<xsl:if test="not(./CreditReference !='')">
																<Ref>
																	<xsl:value-of select="./DocNumber"/>
																</Ref>
															</xsl:if>
														</CdtrRefInf>
													</Strd>
												</xsl:for-each>
											</xsl:if>
										</RmtInf>
									</CdtTrfTxInf>
								</xsl:for-each>
							</PmtInf>
						</xsl:when>
						<xsl:otherwise>
							<!-- SPLIT: NON SEPA ################################################################################
################################################################################################################################# -->
							<!-- Bank C requires names and addresses to be capitalized and limited to the most basic character set, the function 'translate' will be called on every occasion irrespective of the bank (accepted by all banks for Global and Domestic payments, and considered the safest approach). The account 'Bank C - JP' requires the bank account name to be displayed in capitalized half-witdth katakana, the translate function will be used to both capitalize and convert full->half width katakana in case it is necesary. It will also convert any latin character into uppercase and remove some unwanted characters -->
							<PmtInf>
								<PmtInfId>
									<xsl:value-of select="GroupingTag"/>
								</PmtInfId>
								<!-- hardcode 'TRF' for 'Credit Transfer' -->
								<PmtMtd>TRF</PmtMtd>
								<BtchBookg>
									<xsl:value-of select="BatchBooking"/>
								</BtchBookg>
								<NbOfTxs>
									<xsl:value-of select="TotalPayments"/>
								</NbOfTxs>
								<CtrlSum>
									<xsl:value-of select="format-number(TotalAmount,'#.00')"/>
								</CtrlSum>
								<!-- Only populate PmtTpInf for Bank C (only LclInstrm tag with a proprietary code for each bank account). For all Banks, PmtTpInf and other subtags will be generated at transaction level-->
								<xsl:if test="/PaymentBatch/GroupingElements/IntBankAccount/BankName='Bank C'">
									<PmtTpInf>
										<xsl:if test="/PaymentBatch/GroupingElements/IntBankAccount/BankAccountName='Bank C - CA'">
											<LclInstrm>
												<Cd>BKCA780</Cd>
											</LclInstrm>
										</xsl:if>
										<xsl:if test="/PaymentBatch/GroupingElements/IntBankAccount/BankAccountName='Bank C - JP'">
											<LclInstrm>
												<Cd>BKJP410</Cd>
											</LclInstrm>
										</xsl:if>
									</PmtTpInf>
								</xsl:if>
								<ReqdExctnDt>
									<xsl:value-of select="PaymentDate"/>
								</ReqdExctnDt>
								<Dbtr>
									<Nm>
										<xsl:value-of select="translate(translate(/PaymentBatch/GroupingElements/Payer/PayerName,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
									</Nm>
									<PstlAdr>
										<!-- Condition: if address line 2 exists, then concatenate address lines 1 and 2, otherwise populate address line 1 only. It is assumed that Address Line 1 always exists -->
										<xsl:choose>
											<xsl:when test="not(//Payer/Address/AddLine2='')">
												<StrtNm>
													<xsl:value-of select="translate(translate(substring(concat(//Payer/Address/AddLine1,', ',//Payer/Address/AddLine2),1,70),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
												</StrtNm>
											</xsl:when>
											<xsl:otherwise>
												<StrtNm>
													<xsl:value-of select="translate(translate(substring(//Payer/Address/AddLine1,1,70),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
												</StrtNm>
											</xsl:otherwise>
										</xsl:choose>
										<!-- only create the following tags if values to populate them exist -->
										<xsl:if test="not(//Payer/Address/PostalCode='')">
											<PstCd>
												<xsl:value-of select="translate(translate(//Payer/Address/PostalCode,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
											</PstCd>
										</xsl:if>
										<xsl:if test="not(//Payer/Address/City='')">
											<TwnNm>
												<xsl:value-of select="translate(translate(//Payer/Address/City,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
											</TwnNm>
										</xsl:if>
										<xsl:if test="not(//Payer/Address/Country2Digit='')">
											<Ctry>
												<xsl:value-of select="translate(translate(//Payer/Address/Country2Digit,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
											</Ctry>
										</xsl:if>
									</PstlAdr>
									<Id>
										<!-- Condition: If Bank B is used then populate with identifiers provided by the bank, otherwise populate with the payer's tax registration number -->
										<OrgId>
											<Othr>
												<xsl:choose>
													<xsl:when test="/PaymentBatch/GroupingElements/IntBankAccount/BankName='Bank B'">
														<Id>
															<xsl:value-of select="//Payer/PayerCompanyID"/>
														</Id>
														<SchmeNm>
															<Prtry>
																<xsl:value-of select="//Payer/PayerCompanyPrtry"/>
															</Prtry>
														</SchmeNm>
													</xsl:when>
													<xsl:otherwise>
														<xsl:choose>
															<xsl:when test="not(//Payer/TaxID='')">
																<Id>
																	<xsl:value-of select="//Payer/TaxID"/>
																</Id>
																<SchmeNm>
																	<!-- hardcode 'TXID' as Tax Identification Number. A Number assigned by a tax authority to identify an organisation -->
																	<Cd>TXID</Cd>
																</SchmeNm>
															</xsl:when>
															<xsl:otherwise>
																<xsl:if test="not(//Payer/RegistrationCode='')">
																	<Id>
																		<xsl:value-of select="//Payer/RegistrationCode"/>
																	</Id>
																	<SchmeNm>
																		<!-- hardcode 'GS1G' meaning Global Location Number. A non-significant reference number used to identify legal entities, functional entities, or physical entities according to GS1 numbering scheme rules.The number is used to retrieve detailed information that is linked to it -->
																		<Cd>GS1G</Cd>
																	</SchmeNm>
																</xsl:if>
															</xsl:otherwise>
														</xsl:choose>
													</xsl:otherwise>
												</xsl:choose>
											</Othr>
										</OrgId>
									</Id>
								</Dbtr>
								<DbtrAcct>
									<!-- Populate either the internal IBAN or the Bank Account Number in their respective tags, but not both.
									Bank B - NY does not have an IBAN, for instance -->
									<Id>
										<xsl:choose>
											<xsl:when test="not(//IntBankAccount/IBAN='')">
												<IBAN>
													<xsl:value-of select="//IntBankAccount/IBAN"/>
												</IBAN>
											</xsl:when>
											<xsl:otherwise>
												<Othr>
													<Id>
														<xsl:value-of select="//IntBankAccount/BankAccountNumber"/>
													</Id>
												</Othr>
											</xsl:otherwise>
										</xsl:choose>
									</Id>
									<Ccy>
										<xsl:value-of select="//IntBankAccount/Currency"/>
									</Ccy>
								</DbtrAcct>
								<DbtrAgt>
									<FinInstnId>
										<!-- Populate the internal bank account BIC tag only if a BIC exists (all the accounts currently have a BIC code, this is prepared for future  compatibility) -->
										<xsl:if test="not(//IntBankAccount/BICSWIFT='')">
											<BIC>
												<xsl:value-of select="//IntBankAccount/BICSWIFT"/>
											</BIC>
										</xsl:if>
										<!-- Condition: For every internal US based bank account populate the Clearing System Member ID with the 9 digit ABA code. It is assumed that this code exists otherwise the tag will display as empty.
											 As of now only one US based internal bank account exists and it is assigned an ABA code-->
										<xsl:if test="(//IntBankAccount/BankAddress/Country2Digit='US')">
											<ClrSysMmbId>
												<MmbId>
													<xsl:value-of select="//IntBankAccount/RoutingCode/ABA"/>
												</MmbId>
											</ClrSysMmbId>
										</xsl:if>
										<PstlAdr>
											<!-- Condition: if address line 2 exists, then concatenate address lines 1 and 2, otherwise populate address line 1 only. It is assumed that Address Line 1 always exists -->
											<xsl:choose>
												<xsl:when test="not(//IntBankAccount/BankAddress/AddLine2='')">
													<StrtNm>
														<xsl:value-of select="translate(translate(substring(concat(//IntBankAccount/BankAddress/AddLine1,', ',//IntBankAccount/BankAddress/AddLine2),1,70),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
													</StrtNm>
												</xsl:when>
												<xsl:otherwise>
													<StrtNm>
														<xsl:value-of select="translate(translate(substring(//IntBankAccount/BankAddress/AddLine1,1,70),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
													</StrtNm>
												</xsl:otherwise>
											</xsl:choose>
											<!-- only create the following tags if values to populate them exist -->
											<xsl:if test="not(//IntBankAccount/BankAddress/PostalCode='')">
												<PstCd>
													<xsl:value-of select="translate(translate(//IntBankAccount/BankAddress/PostalCode,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
												</PstCd>
											</xsl:if>
											<xsl:if test="not(//IntBankAccount/BankAddress/City='')">
												<TwnNm>
													<xsl:value-of select="translate(translate(//IntBankAccount/BankAddress/City,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
												</TwnNm>
											</xsl:if>
											<xsl:if test="not(//IntBankAccount/BankAddress/Country2Digit='')">
												<Ctry>
													<xsl:value-of select="//IntBankAccount/BankAddress/Country2Digit"/>
												</Ctry>
											</xsl:if>
										</PstlAdr>
									</FinInstnId>
								</DbtrAgt>
								<!-- Iteration: loop through all grouping tags -->
								<xsl:for-each select="key('index-GroupID', ./GroupingTag)">
									<xsl:sort select="./GroupingTag"/>
									<CdtTrfTxInf>
										<PmtId>
											<InstrId>
												<xsl:value-of select="./PmtDocumentNum"/>
											</InstrId>
											<EndToEndId>
												<xsl:value-of select="./PmtDocumentNum"/>
											</EndToEndId>
										</PmtId>
										<!-- The below PmtTpInf subtags adds to the data already populated in the same tag at payment level -->
										<PmtTpInf>
											<!-- Multiple conditions apply to the SvcLvl tag.
											For Bank A and C, and also for Bank B (UK account - for future compatibility, cuurently no global payments are processed), only two values are possible: NURG or URGP. Default is NURG, but if PmtPriority tag is populated in the extract, the SvcLvl/Cd tag should inherit that value (to allow the user to override the default)
											For Bank B (NY account) the rules are more complex and are evaluated in the following order:
											1 - If The payee bank is also Bank B then the value should be BKTR (book transfer).
											2 - If 1 does not verify, whenever a payee bank account 9-digit ABA routing code or 6-digit CHIPS ID is provided the value should be NURG (ACH).
											3 - If 1 and 2 don't apply, then populate with URGP (cross-border payment with or without intermediary details depending on whether they exist).

NURG 	Non-Urgent Payment		Payment must be executed as a non-urgent transaction, which is typically identified as an ACH or low value transaction
BKTR 	Book Transaction		Payment through internal book transfer
URGP 	Urgent Payment			Payment must be executed as an urgent transaction cleared through a real-time gross settlement system, which is typically identified as a wire or high value transaction
-->
											<SvcLvl>
												<xsl:choose>
													<xsl:when test="(//IntBankAccount/BankName='Bank A') or (//IntBankAccount/BankName='Bank C') or (//IntBankAccount/BankAccountName='Bank B - UK')">
														<xsl:if test="not(./PmtPriority='')">
															<Cd>
																<xsl:value-of select="./PmtPriority"/>
															</Cd>
														</xsl:if>
														<xsl:if test="(./PmtPriority='')">
															<Cd>NURG</Cd>
														</xsl:if>
													</xsl:when>
													<xsl:when test="(//IntBankAccount/BankAccountName='Bank B - NY')">
														<xsl:if test="(./PayeeBankAccount/BankName='Bank B')">
															<Cd>BKTR</Cd>
														</xsl:if>
														<xsl:if test="(./PayeeBankAccount/BankName!='Bank B') and (not(./PayeeBankAccount/RoutingCode/ABA='') or not(./PayeeBankAccount/RoutingCode/CHIPS=''))">
															<Cd>NURG</Cd>
														</xsl:if>
														<xsl:if test="(./PayeeBankAccount/BankName!='Bank B') and ((./PayeeBankAccount/RoutingCode/ABA='') and (./PayeeBankAccount/RoutingCode/CHIPS=''))">
															<Cd>URGP</Cd>
														</xsl:if>
													</xsl:when>
													<xsl:otherwise>
														<Cd>URGP</Cd>
													</xsl:otherwise>
												</xsl:choose>
											</SvcLvl>
											<!-- Local Instrument is only used for 'Bank B - NY' account for NURG payments (ACH), with the value 'PPD'. A condition is defined to create the tag if PmtPriority = NURG

PPD		Prearranged Payment or Deposit		Transaction is related to prearranged payment or deposit consumer counterparty												-->
											<xsl:if test="(//IntBankAccount/BankAccountName='Bank B - NY') and ((./PayeeBankAccount/BankName!='Bank B') and (not(./PayeeBankAccount/RoutingCode/ABA='') or not(./PayeeBankAccount/RoutingCode/CHIPS='')))">
												<LclInstrm>
													<Cd>PPD</Cd>
												</LclInstrm>
											</xsl:if>
											<!-- The category purpose is derived from the PayeeType tag in the extract. Only the following values are possible:
PayeeType		CtgyPurp	Description
Employee		SALA		Salary Payment
Consultant		SALA		Salary Payment
Pre-Employment	SALA		Salary Payment
Vendor			SUPP		Supplier Payment
-->
											<CtgyPurp>
												<xsl:choose>
													<xsl:when test="(Payee/PayeeType='Vendor')">
														<Cd>SUPP</Cd>
													</xsl:when>
													<xsl:when test="((Payee/PayeeType='Employee') or (Payee/PayeeType='Consultant') or (Payee/PayeeType='Pre-Employment'))">
														<Cd>SALA</Cd>
													</xsl:when>
													<xsl:otherwise>
														<Cd>SUPP</Cd>
													</xsl:otherwise>
												</xsl:choose>
											</CtgyPurp>
										</PmtTpInf>
										<Amt>
											<InstdAmt>
												<xsl:attribute name="Ccy">
													<xsl:value-of select="./PaymentAmount/Currency"/>
												</xsl:attribute>
												<!-- If the currency is JPY, KRW or VND change the precision and remove decimal places  -->
												<xsl:choose>
													<xsl:when test="((./PaymentAmount/Currency='JPY') or (./PaymentAmount/Currency='KRW') or (./PaymentAmount/Currency='VND'))">
														<xsl:value-of select="format-number(./PaymentAmount/Value,'#')"/>
													</xsl:when>
													<xsl:otherwise>
														<xsl:value-of select="format-number(./PaymentAmount/Value,'#.00')"/>
													</xsl:otherwise>
												</xsl:choose>
											</InstdAmt>
										</Amt>
										<!-- If the ChargeBearer tag is populated in the extract, then populate the ChrgBr tag with the same value (used to override default values if necessary). If null, then the value needs to be derived from the PayeeType tag in the extract. Only the following values are possible:
PayeeType		ChrgBr	Description
Employee		DEBT		Debitor
Consultant		DEBT		Debitor
Pre-Employment	DEBT		Debitor
Vendor			SHAR		Shared
-->
										<xsl:choose>
											<xsl:when test="not(BankCharges/ChargeBearer='')">
												<ChrgBr>
													<xsl:value-of select="BankCharges/ChargeBearer"/>
												</ChrgBr>
											</xsl:when>
											<xsl:when test="(Payee/PayeeType='Vendor')">
												<ChrgBr>SHAR</ChrgBr>
											</xsl:when>
											<xsl:when test="((Payee/PayeeType='Employee') or (Payee/PayeeType='Consultant') or (Payee/PayeeType='Pre-Employment'))">
												<ChrgBr>DEBT</ChrgBr>
											</xsl:when>
											<xsl:otherwise>
												<ChrgBr>SHAR</ChrgBr>
											</xsl:otherwise>
										</xsl:choose>
										<!-- Logic for displaying Intermediary Bank:
										0. The tag IntrmyAgt1 should only be created if a relationship exists.
										1. Only applicable to 'Bank B - NY', for cross border payments, and the payee has no account in Bank B (this would make it a Booked Transfer)
										2. If intermediary BIC is available, provide BIC (should always be the case)
										3. Depending upon the beneficiary bank country:
											3.1 For US
												3.1.1 If CHIPS ABA available, provide this
												3.1.2 If CHIPS UID is available, provide this
												3.1.3 else provide bank account number
											3.2 For Non-US
												3.2.1 always provide bank account number (no IBAN)
											3.3 (for US and non-US) Provide Bank Name and full Bank Branch address -->
										<xsl:if test="(//IntBankAccount/BankAccountName='Bank B - NY') and (PayeeBankAccount/BankName!='Bank B') and (PayeeBankAccount/RoutingCode/CHIPS='') and not(PayeeBankAccount/IntermediaryBankAccount1/BankName='')">
											<IntrmyAgt1>
												<FinInstnId>
													<xsl:if test="not(PayeeBankAccount/IntermediaryBankAccount1/BICSWIFT='')">
														<BIC>
															<xsl:value-of select="PayeeBankAccount/IntermediaryBankAccount1/BICSWIFT"/>
														</BIC>
													</xsl:if>
													<ClrSysMmbId>
														<MmbId>
															<xsl:value-of select="PayeeBankAccount/IntermediaryBankAccount1/RoutingCode/CHIPS"/>
														</MmbId>
													</ClrSysMmbId>
													<xsl:if test="not(PayeeBankAccount/IntermediaryBankAccount1/BankName='')">
														<Nm>
															<xsl:value-of select="translate(translate(PayeeBankAccount/IntermediaryBankAccount1/BankName,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
														</Nm>
													</xsl:if>
													<PstlAdr>
														<!-- Condition: if address line 2 exists, then concatenate address lines 1 and 2, otherwise populate address line 1 only. It is assumed that Address Line 1 always exists -->
														<xsl:choose>
															<xsl:when test="not(PayeeBankAccount/IntermediaryBankAccount1/Address/AddLine2='')">
																<StrtNm>
																	<xsl:value-of select="translate(translate(substring(concat(PayeeBankAccount/IntermediaryBankAccount1/Address/AddLine1,', ',PayeeBankAccount/IntermediaryBankAccount1/Address/AddLine2),1,70),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
																</StrtNm>
															</xsl:when>
															<xsl:otherwise>
																<StrtNm>
																	<xsl:value-of select="translate(translate(substring(PayeeBankAccount/IntermediaryBankAccount1/Address/AddLine1,1,70),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
																</StrtNm>
															</xsl:otherwise>
														</xsl:choose>
														<!-- only create the following tags if values to populate them exist -->
														<xsl:if test="not(PayeeBankAccount/IntermediaryBankAccount1/Address/PostalCode='')">
															<PstCd>
																<xsl:value-of select="translate(translate(PayeeBankAccount/IntermediaryBankAccount1/Address/PostalCode,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
															</PstCd>
														</xsl:if>
														<xsl:if test="not(PayeeBankAccount/IntermediaryBankAccount1/Address/City='')">
															<TwnNm>
																<xsl:value-of select="translate(translate(PayeeBankAccount/IntermediaryBankAccount1/Address/City,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
															</TwnNm>
														</xsl:if>
														<xsl:if test="not(PayeeBankAccount/IntermediaryBankAccount1/Address/Country2Digit='')">
															<Ctry>
																<xsl:value-of select="PayeeBankAccount/IntermediaryBankAccount1/Address/Country2Digit"/>
															</Ctry>
														</xsl:if>
													</PstlAdr>
												</FinInstnId>
											</IntrmyAgt1>
										</xsl:if>
										<!-- Only create the CdtrAgt tag and its subtags if:
										1. Payee bank account BIC/SWIFT exists and populate the BIC tag with that value;
										or
										2. For 'Bank B', populate the ClrSysMmbID/MmbID tag concatenating the bank branch 2-digit country code (from the payee bank address) with the payee bank account routing code -->
										<xsl:if test="not(PayeeBankAccount/BICSWIFT='') or ( (//IntBankAccount/BankAccountName='Bank B - NY') and (not(PayeeBankAccount/RoutingCode/RtgCode='')) or not(PayeeBankAccount/RoutingCode/ABA='') or not(PayeeBankAccount/RoutingCode/CHIPS='') )">
											<CdtrAgt>
												<FinInstnId>
													<xsl:if test="not(PayeeBankAccount/BICSWIFT='')">
														<BIC>
															<xsl:value-of select="PayeeBankAccount/BICSWIFT"/>
														</BIC>
													</xsl:if>
													<!-- NOTE: It is unclear if we need to extend the condition to exclude US bank accounts -->
													<xsl:if test="(//IntBankAccount/BankName='Bank B') and ((not(PayeeBankAccount/RoutingCode/RtgCode='') or not(PayeeBankAccount/RoutingCode/ABA='') or not(PayeeBankAccount/RoutingCode/CHIPS='')))">
														<ClrSysMmbId>
															<MmbId>
																<xsl:if test="not(PayeeBankAccount/RoutingCode/RtgCode='')">
																	<xsl:value-of select="PayeeBankAccount/BankAddress/Country2Digit"/>
																	<xsl:value-of select="PayeeBankAccount/RoutingCode/RtgCode"/>
																</xsl:if>
																<xsl:if test="not(PayeeBankAccount/RoutingCode/ABA='') and (PayeeBankAccount/RoutingCode/CHIPS='')">
																	<xsl:value-of select="concat('ABA',PayeeBankAccount/RoutingCode/ABA)"/>
																</xsl:if>
																<xsl:if test="not(PayeeBankAccount/RoutingCode/CHIPS='') and (PayeeBankAccount/RoutingCode/ABA='')">
																	<xsl:value-of select="concat('CHIPS',PayeeBankAccount/RoutingCode/CHIPS)"/>
																</xsl:if>
															</MmbId>
														</ClrSysMmbId>
													</xsl:if>
													<xsl:if test="(//IntBankAccount/BankName='Bank C') and (not(PayeeBankAccount/RoutingCode/RtgCode=''))">
														<ClrSysMmbId>
															<MmbId>
																<xsl:value-of select="PayeeBankAccount/RoutingCode/RtgCode"/>
															</MmbId>
														</ClrSysMmbId>
													</xsl:if>
													<!-- NOTE: Bank A is unable to read the structured address despite the info provided in the documentation. The proposed solution is to concatenate all the address elements under the <Nm> tag. Structured address is provided for other banks.
													It was decided to still leave the structured tags even if Bank A is not able to read them -->
													<xsl:choose>
														<xsl:when test="//IntBankAccount/BankName='Bank A'">
															<Nm>
																<xsl:value-of select="translate(translate(substring(concat(
										  PayeeBankAccount/BankName,
										  ' - '
										  ,PayeeBankAccount/BranchNumber,
										  ' / '
										  ,PayeeBankAccount/BankAddress/AddLine1,
										  ', '
										  ,PayeeBankAccount/BankAddress/AddLine2,
										  ', '
										  ,PayeeBankAccount/BankAddress/City,
										  ', '
										  ,PayeeBankAccount/BankAddress/PostalCode,
										  ', '
										  ,PayeeBankAccount/BankAddress/CountryName),1,140),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
															</Nm>
														</xsl:when>
														<xsl:when test="//IntBankAccount/BankName!='Bank A'">
															<Nm>
																<xsl:value-of select="translate(translate(PayeeBankAccount/BankName,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
															</Nm>
														</xsl:when>
													</xsl:choose>
													<PstlAdr>
														<!-- Condition: if address line 2 exists, then concatenate address lines 1 and 2, otherwise populate address line 1 only. It is assumed that Address Line 1 always exists -->
														<!-- NOTE: 'Bank C - JP' account should only populate the Ctry tag of the structured address. This is related to the fact that the elements of the address are not presented in Katakana -->
														<xsl:if test=" not(//IntBankAccount/BankAccountName='Bank C - JP')">
															<xsl:choose>
																<xsl:when test="not(PayeeBankAccount/BankAddress/AddLine2='')">
																	<StrtNm>
																		<xsl:value-of select="translate(translate(substring(concat(PayeeBankAccount/BankAddress/AddLine1,', ',PayeeBankAccount/BankAddress/AddLine2),1,70),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
																	</StrtNm>
																</xsl:when>
																<xsl:otherwise>
																	<StrtNm>
																		<xsl:value-of select="translate(translate(substring(PayeeBankAccount/BankAddress/AddLine1,1,70),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
																	</StrtNm>
																</xsl:otherwise>
															</xsl:choose>
															<!-- only create the following tags if values to populate them exist -->
															<xsl:if test="not(PayeeBankAccount/BankAddress/PostalCode='') and (//IntBankAccount/BankAccountName!='Bank C - JP')">
																<PstCd>
																	<xsl:value-of select="translate(translate(PayeeBankAccount/BankAddress/PostalCode,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
																</PstCd>
															</xsl:if>
															<xsl:if test="not(PayeeBankAccount/BankAddress/City='') and (//IntBankAccount/BankAccountName!='Bank C - JP')">
																<TwnNm>
																	<xsl:value-of select="translate(translate(PayeeBankAccount/BankAddress/City,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
																</TwnNm>
															</xsl:if>
														</xsl:if>
														<xsl:if test="not(PayeeBankAccount/BankAddress/Country2Digit='')">
															<Ctry>
																<xsl:value-of select="PayeeBankAccount/BankAddress/Country2Digit"/>
															</Ctry>
														</xsl:if>
													</PstlAdr>
													<!-- Bank A requires the routing code to be presented in Othr/Id and the 2-digit country code in SchmeNm/Prtry -->
													<xsl:if test="(//IntBankAccount/BankAccountName='Bank A - EU') and (not(PayeeBankAccount/RoutingCode/RtgCode=''))">
														<Othr>
															<Id>
																<xsl:value-of select="PayeeBankAccount/RoutingCode/RtgCode"/>
															</Id>
															<SchmeNm>
																<Prtry>
																	<xsl:value-of select="PayeeBankAccount/BankAddress/Country2Digit"/>
																</Prtry>
															</SchmeNm>
														</Othr>
													</xsl:if>
												</FinInstnId>
											</CdtrAgt>
										</xsl:if>
										<Cdtr>
											<!-- Different rules apply to the Cdtr/Nm tag. The general rule is to populate with the value of capitalized basic latin PayeeBankAccount/BankAccountName and limited to 140 characters. The exception is for 'Bank C - JP' account which is expected to populate the tag with the bank account name in half-width katakana. The rule is: if an alternate bank account name exists, then provide this value limited to 140 characters, otherwise provide the same as for other cases.
											A function translates full width katakana into half width (difficult to spot the differences) and removes unwanted characters	-->
											<xsl:choose>
												<xsl:when test="(//IntBankAccount/BankAccountName='Bank C - JP') and (not(PayeeBankAccount/BankAccountNameAlt1=''))">
													<Nm>
														<xsl:value-of select="translate(substring(PayeeBankAccount/BankAccountNameAlt1,1,140),$jpfwkatakana,$jphwkatakana)"/>
													</Nm>
												</xsl:when>
												<xsl:otherwise>
													<Nm>
														<xsl:value-of select="translate(translate(substring(PayeeBankAccount/BankAccountName,1,140),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
													</Nm>
												</xsl:otherwise>
											</xsl:choose>
											<!-- NOTE: A thorough cleanup of master data is recommended and the use of alphabets other than basic latin can cause rejections from the banks -->
											<PstlAdr>
												<!-- Condition: if address line 2 exists, then concatenate address lines 1 and 2, otherwise populate address line 1 only. It is assumed that Address Line 1 always exists -->
												<xsl:choose>
													<xsl:when test="not(Payee/Address/AddLine2='')">
														<StrtNm>
															<xsl:value-of select="translate(translate(substring(concat(Payee/Address/AddLine1,', ',Payee/Address/AddLine2),1,70),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
														</StrtNm>
													</xsl:when>
													<xsl:otherwise>
														<StrtNm>
															<xsl:value-of select="translate(translate(substring(Payee/Address/AddLine1,1,70),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
														</StrtNm>
													</xsl:otherwise>
												</xsl:choose>
												<!-- only create the following tags if values to populate them exist -->
												<xsl:if test="not(Payee/Address/PostalCode='')">
													<PstCd>
														<xsl:value-of select="translate(translate(Payee/Address/PostalCode,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
													</PstCd>
												</xsl:if>
												<xsl:if test="not(Payee/Address/City='')">
													<TwnNm>
														<xsl:value-of select="translate(translate(Payee/Address/City,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
													</TwnNm>
												</xsl:if>
												<xsl:if test="not(Payee/Address/Country2Digit='')">
													<Ctry>
														<xsl:value-of select="translate(translate(Payee/Address/Country2Digit,$extlatin,$basiclatin),$lowercase,$uppercase)"/>
													</Ctry>
												</xsl:if>
											</PstlAdr>
											<!-- Bank B does not require the Id tags and subtags to be populated, but no exception will be defined. Tags will be populated whenever data is available -->
											<xsl:if test="not(Payee/TaxID='') and ((PayeeBankAccount/BankAddress/Country2Digit='AR') or (PayeeBankAccount/BankAddress/Country2Digit='AZ') or (PayeeBankAccount/BankAddress/Country2Digit='BR') or (PayeeBankAccount/BankAddress/Country2Digit='BY') or (PayeeBankAccount/BankAddress/Country2Digit='CO') or (PayeeBankAccount/BankAddress/Country2Digit='HN') or (PayeeBankAccount/BankAddress/Country2Digit='KZ') or (PayeeBankAccount/BankAddress/Country2Digit='MZ') or (PayeeBankAccount/BankAddress/Country2Digit='PE') or (PayeeBankAccount/BankAddress/Country2Digit='PY') or (PayeeBankAccount/BankAddress/Country2Digit='RU'))">
												<Id>
													<OrgId>
														<Othr>
															<Id>
																<xsl:value-of select="Payee/TaxID"/>
															</Id>
															<SchmeNm>
																<Cd>TXID</Cd>
															</SchmeNm>
														</Othr>
													</OrgId>
												</Id>
											</xsl:if>
										</Cdtr>
										<!-- NOTE: Contrary to the provided specifications, Bank A does not accept the IBAN being populated in the IBAN tag for a few countries, but it recommends to place the IBAN in the tag reserved for the bank account (?!). This is for countries in transition or that recently adopted IBAN.
										Modifying the configuration on the IBAN setup form for these countries would not resolve the issue.										-->
										<!-- list of exceptions for Bank A:
EY	Egypt
CI 	Ivory Coast
KZ	Kazakhstan
SC	Seychelles
-->
										<CdtrAcct>
											<xsl:choose>
												<xsl:when test="not(//IntBankAccount/BankName='Bank A') and (not(PayeeBankAccount/IBAN=''))">
													<Id>
														<IBAN>
															<xsl:value-of select="PayeeBankAccount/IBAN"/>
														</IBAN>
													</Id>
												</xsl:when>
												<xsl:when test="not(//IntBankAccount/BankName='Bank A') and (not(PayeeBankAccount/BankAccountNumber=''))">
													<Id>
														<Othr>
															<Id>
																<xsl:value-of select="PayeeBankAccount/BankAccountNumber"/>
															</Id>
														</Othr>
													</Id>
												</xsl:when>
												<xsl:when test="(//IntBankAccount/BankName='Bank A') and (not(PayeeBankAccount/IBAN='')) and ( not(PayeeBankAccount/BankAddress/Country2Digit='EY') and not(PayeeBankAccount/BankAddress/Country2Digit='CI') and not(PayeeBankAccount/BankAddress/Country2Digit='KZ') and not(PayeeBankAccount/BankAddress/Country2Digit='SC'))">
													<Id>
														<IBAN>
															<xsl:value-of select="PayeeBankAccount/IBAN"/>
														</IBAN>
													</Id>
												</xsl:when>
												<xsl:when test="(//IntBankAccount/BankName='Bank A') and (not(PayeeBankAccount/IBAN='')) and ( (PayeeBankAccount/BankAddress/Country2Digit='EY') or (PayeeBankAccount/BankAddress/Country2Digit='CI') or (PayeeBankAccount/BankAddress/Country2Digit='KZ') or (PayeeBankAccount/BankAddress/Country2Digit='SC'))">
													<Id>
														<Othr>
															<Id>
																<xsl:value-of select="PayeeBankAccount/IBAN"/>
															</Id>
														</Othr>
													</Id>
												</xsl:when>
												<!-- Contrary to the specifications from Bank A, several countries require concatenation of the routing codes / bank and branch identifiers with the bank account number. Bank A does not read the dedicated tag for routing details for such countries.
													Zambia and the Bahamas have specific requirements to provide routing details for specific cases depending on the payee bank, but after consulting with Bank A it is OK to always provide the routing code.
The list of countries is:
AU, BD, BS, CA, CN, GB, GG, GY, IM, IN, JE, JP, KG, MY, NZ, RW, TW, US, ZA, ZM													-->
												<xsl:when test="(//IntBankAccount/BankName='Bank A') and (PayeeBankAccount/BankAddress/Country2Digit='AU' or PayeeBankAccount/BankAddress/Country2Digit='BD' or PayeeBankAccount/BankAddress/Country2Digit='BS' or PayeeBankAccount/BankAddress/Country2Digit='CA' or PayeeBankAccount/BankAddress/Country2Digit='CN' or PayeeBankAccount/BankAddress/Country2Digit='GB' or PayeeBankAccount/BankAddress/Country2Digit='GG' or PayeeBankAccount/BankAddress/Country2Digit='GY' or PayeeBankAccount/BankAddress/Country2Digit='IM' or PayeeBankAccount/BankAddress/Country2Digit='IN' or PayeeBankAccount/BankAddress/Country2Digit='JE' or PayeeBankAccount/BankAddress/Country2Digit='JP' or PayeeBankAccount/BankAddress/Country2Digit='KG' or PayeeBankAccount/BankAddress/Country2Digit='MY' or PayeeBankAccount/BankAddress/Country2Digit='NZ' or PayeeBankAccount/BankAddress/Country2Digit='RW' or PayeeBankAccount/BankAddress/Country2Digit='TW' or PayeeBankAccount/BankAddress/Country2Digit='US' or PayeeBankAccount/BankAddress/Country2Digit='ZA' or PayeeBankAccount/BankAddress/Country2Digit='ZM')">
													<Id>
														<Othr>
															<Id>
																<xsl:value-of select="PayeeBankAccount/RoutingCode/RtgCode"/>
																<xsl:value-of select="PayeeBankAccount/BankAccountNumber"/>
															</Id>
														</Othr>
													</Id>
												</xsl:when>
											</xsl:choose>
											<!-- NOTE: - add logic for 'Bank C - JP' account Savings/Checking/SpSavings/Other account type.
											A new tag 'AccountType' had to be created in the extract holding one of the values below (or null) and master data for bank account holders in Japan had to be enriched. A proprietary code is mapped against each of these values:
VALUE			MAPPED TO
Checking		TO
Savings			FU
Special Savings	TI
Other			SO

If AccountType is null, map to Checking (TO)
-->
											<xsl:if test="(//IntBankAccount/BankAccountName='Bank C - JP')">
												<Tp>
													<xsl:if test="(PayeeBankAccount/AccountType='Checking') or (PayeeBankAccount/AccountType='')">
														<Prtry>TO</Prtry>
													</xsl:if>
													<xsl:if test="(PayeeBankAccount/AccountType='Savings')">
														<Prtry>FU</Prtry>
													</xsl:if>
													<xsl:if test="(PayeeBankAccount/AccountType='Special Savings')">
														<Prtry>TI</Prtry>
													</xsl:if>
													<xsl:if test="(PayeeBankAccount/AccountType='Other')">
														<Prtry>SO</Prtry>
														<!-- OTHER -->
													</xsl:if>
												</Tp>
											</xsl:if>
										</CdtrAcct>
										<!-- For bank B, beneficiary email and phones to be provided in InstrForCdtrAgt/InstrInf for some countries. Concatenate this information in the Special Instructions for Payee (SpecialInstSupp) and remove leading/trailing/double spaces through function normalize-space() and limit to 140 characters.
										For other banks populate the tag with SpecialInstrSupp if it exists
The list of countries is: BA, BD, BF, BJ ,BR ,CA ,CF ,CG ,CI ,CM, CN,CO ,GA ,GW ,ID ,IN ,JP ,KR ,ML ,NE ,PF ,PH ,RU ,SN ,TD ,TG ,TH ,TW -->
										<xsl:choose>
											<xsl:when test="(//IntBankAccount/BankName='Bank B') and ((not(Payee/ContactDetails/PhoneNumber='') or not(Payee/ContactDetails/Email='')) or (not(./PaymentDetail/SpecialInstrSupp='') and (PayeeBankAccount/BankAddress/Country2Digit='BA' or PayeeBankAccount/BankAddress/Country2Digit='BD' or PayeeBankAccount/BankAddress/Country2Digit='BF' or PayeeBankAccount/BankAddress/Country2Digit='BJ' or PayeeBankAccount/BankAddress/Country2Digit='BR' or PayeeBankAccount/BankAddress/Country2Digit='CA' or PayeeBankAccount/BankAddress/Country2Digit='CF' or PayeeBankAccount/BankAddress/Country2Digit='CG' or PayeeBankAccount/BankAddress/Country2Digit='CI' or PayeeBankAccount/BankAddress/Country2Digit='CM' or PayeeBankAccount/BankAddress/Country2Digit='CN' or PayeeBankAccount/BankAddress/Country2Digit='CO' or PayeeBankAccount/BankAddress/Country2Digit='GA' or PayeeBankAccount/BankAddress/Country2Digit='GW' or PayeeBankAccount/BankAddress/Country2Digit='ID' or PayeeBankAccount/BankAddress/Country2Digit='IN' or PayeeBankAccount/BankAddress/Country2Digit='JP' or PayeeBankAccount/BankAddress/Country2Digit='KR' or PayeeBankAccount/BankAddress/Country2Digit='ML' or PayeeBankAccount/BankAddress/Country2Digit='NE' or PayeeBankAccount/BankAddress/Country2Digit='PF' or PayeeBankAccount/BankAddress/Country2Digit='PH' or PayeeBankAccount/BankAddress/Country2Digit='RU' or PayeeBankAccount/BankAddress/Country2Digit='SN' or PayeeBankAccount/BankAddress/Country2Digit='TD' or PayeeBankAccount/BankAddress/Country2Digit='TG' or PayeeBankAccount/BankAddress/Country2Digit='TH' or PayeeBankAccount/BankAddress/Country2Digit='TW')))">
												<InstrForCdtrAgt>
													<InstrInf>
														<xsl:value-of select="translate(translate(substring(normalize-space(concat(Payee/ContactDetails/PhoneNumber,' ',Payee/ContactDetails/Email,' ',./SpecialInstrSupp)),1,140),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
													</InstrInf>
												</InstrForCdtrAgt>
											</xsl:when>
											<xsl:when test="not(//IntBankAccount/BankName='Bank B') and not(./SpecialInstrSupp='')">
												<InstrForCdtrAgt>
													<InstrInf>
														<xsl:value-of select="translate(translate(substring(./SpecialInstrSupp,1,140),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
													</InstrInf>
												</InstrForCdtrAgt>
											</xsl:when>
										</xsl:choose>
										<!-- If SpecialInstrBank exists in the extract, populate it in InstrForDbtrAgt. -->
										<!-- NOTE:	Bank A is unable to read the 140 characters for the bank account name (can only process 70 chr). A workaround was proposed and use the InstrForDbtrAgt whenever the length of the bank account name exceeds 70 chr. Concatenate with SpecialInstrBank and payee contact details for the provided list of countries, remove lead/trailing/double spaces and substring to 140 chr. 
										Length of the string can be evaluated through the string-length() function
										This tag will also present the payee contact details for the same countries as Bank B. Store it in a variable and concatenate. -->
										<xsl:if test="(//IntBankAccount/BankName='Bank A') and ( not(Payee/ContactDetails/PhoneNumber='') or not(Payee/ContactDetails/Email='')) and ((PayeeBankAccount/BankAddress/Country2Digit='BA' or PayeeBankAccount/BankAddress/Country2Digit='BD' or PayeeBankAccount/BankAddress/Country2Digit='BF' or PayeeBankAccount/BankAddress/Country2Digit='BJ' or PayeeBankAccount/BankAddress/Country2Digit='BR' or PayeeBankAccount/BankAddress/Country2Digit='CA' or PayeeBankAccount/BankAddress/Country2Digit='CF' or PayeeBankAccount/BankAddress/Country2Digit='CG' or PayeeBankAccount/BankAddress/Country2Digit='CI' or PayeeBankAccount/BankAddress/Country2Digit='CM' or PayeeBankAccount/BankAddress/Country2Digit='CN' or PayeeBankAccount/BankAddress/Country2Digit='CO' or PayeeBankAccount/BankAddress/Country2Digit='GA' or PayeeBankAccount/BankAddress/Country2Digit='GW' or PayeeBankAccount/BankAddress/Country2Digit='ID' or PayeeBankAccount/BankAddress/Country2Digit='IN' or PayeeBankAccount/BankAddress/Country2Digit='JP' or PayeeBankAccount/BankAddress/Country2Digit='KR' or PayeeBankAccount/BankAddress/Country2Digit='ML' or PayeeBankAccount/BankAddress/Country2Digit='NE' or PayeeBankAccount/BankAddress/Country2Digit='PF' or PayeeBankAccount/BankAddress/Country2Digit='PH' or PayeeBankAccount/BankAddress/Country2Digit='RU' or PayeeBankAccount/BankAddress/Country2Digit='SN' or PayeeBankAccount/BankAddress/Country2Digit='TD' or PayeeBankAccount/BankAddress/Country2Digit='TG' or PayeeBankAccount/BankAddress/Country2Digit='TH' or PayeeBankAccount/BankAddress/Country2Digit='TW'))">
											<xsl:variable name="payeecontact">
												<xsl:value-of select="normalize-space(concat(Payee/ContactDetails/PhoneNumber,' ',Payee/ContactDetails/Email))"/>
											</xsl:variable>
											<xsl:if test="(string-length(./PayeeBankAccount/BankAccountName)>70)">
												<InstrForDbtrAgt>
													<xsl:value-of select="translate(translate(substring(normalize-space(concat(PayeeBankAccount/BankAccountName,' ',./SpecialInstrBank,' ',$payeecontact)),1,140),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
												</InstrForDbtrAgt>
											</xsl:if>
											<xsl:if test="not(string-length(./PayeeBankAccount/BankAccountName)>70)">
												<InstrForDbtrAgt>
													<xsl:value-of select="translate(translate(substring(normalize-space(concat(./SpecialInstrBank,' ',$payeecontact)),1,140),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
												</InstrForDbtrAgt>
											</xsl:if>
										</xsl:if>
										<xsl:if test="not(//IntBankAccount/BankName='Bank A') and (not(./SpecialInstrBank=''))">
											<InstrForDbtrAgt>
												<xsl:value-of select="translate(translate(substring(./SpecialInstrBank,1,140),$extlatin,$basiclatin),$lowercase,$uppercase)"/>
											</InstrForDbtrAgt>
										</xsl:if>
										<RmtInf>
											<!-- Condition: the tag 'StructuredRem' triggers the use of a structured remittance details (Y) or unstructured (N). If a Structured remittance is used, display the Ustrd tag as well for all banks and profiles.
											Multiple instances of Ustrd can be created, Bank A only uses one instance and an exception must be added for Bank A. This may cause problems whenever many documents are paid simultaneously as we may not have much room to state the purpose of payment.
											The rule is:
											- Loop all documents paid and concatenate documentnumber;documentamount;paymentamount;purposeofpayment|
											- If the transaction is a credit memo (not CINV), display the amounts as negative
											- if no purpose of payment is provided, default 'Payment for Goods and Services'
											- substring to 140 characters (always)
											Use the variable remittancemsg to store the entire string, in order to substring it to 140 characters after the entire tag has been created. -->
											<xsl:if test="(./StructuredRem='N')">
												<xsl:variable name="remittancemsg">
													<xsl:for-each select="./PayableDocuments">
														<xsl:value-of select="./DocNumber"/>
														<xsl:choose>
															<xsl:when test="./DocType='CINV'">
																<xsl:value-of select="concat(';',./DocAmount/Value,';',./PaymentAmount/Value,';')"/>
															</xsl:when>
															<xsl:otherwise>
																<xsl:value-of select="concat(';-',./DocAmount/Value,';-',./PaymentAmount/Value,';')"/>
															</xsl:otherwise>
														</xsl:choose>
														<xsl:if test="not(./PurpPayment/DisplayValue='')">
															<xsl:value-of select="concat(./PurpPayment/DisplayValue,'|')"/>
														</xsl:if>
														<xsl:if test="./PurpPayment/DisplayValue=''">Payment for Goods and Services|</xsl:if>
													</xsl:for-each>
												</xsl:variable>
												<xsl:if test="not(//IntBankAccount/BankName='Bank A')">
													<xsl:for-each select="./PayableDocuments">
														<xsl:variable name="remittancemsgmult">
															<xsl:value-of select="./DocNumber"/>
															<xsl:choose>
																<xsl:when test="./DocType='CINV'">
																	<xsl:value-of select="concat(';',./DocAmount/Value,';',./PaymentAmount/Value,';')"/>
																</xsl:when>
																<xsl:otherwise>
																	<xsl:value-of select="concat(';-',./DocAmount/Value,';-',./PaymentAmount/Value,';')"/>
																</xsl:otherwise>
															</xsl:choose>
															<xsl:if test="not(./PurpPayment/DisplayValue='')">
																<xsl:value-of select="concat(./PurpPayment/DisplayValue,'|')"/>
															</xsl:if>
															<xsl:if test="./PurpPayment/DisplayValue=''">Payment for Goods and Services|</xsl:if>
														</xsl:variable>
														<Ustrd>
															<xsl:value-of select="substring($remittancemsgmult,1,140)"/>
														</Ustrd>
													</xsl:for-each>
												</xsl:if>
												<xsl:if test="(//IntBankAccount/BankName='Bank A')">
													<Ustrd>
														<xsl:value-of select="substring($remittancemsg,1,140)"/>
													</Ustrd>
												</xsl:if>
											</xsl:if>
											<xsl:if test="(./StructuredRem='Y')">
												<!-- Multiple conditions: if the document type is CINV (invoice) then the tag RmtdAmt tag must be used to provide the amount and currency. If the document type is CREN (credit note) then the tag CdtNoteAmt must be used instead.
												If an ISO Credit Reference has been generated, then it will be used in the Ref tag (prefixed with 'RF' and 2 check digit and concatenated with the document number) and the Issr tag gets populated with 'ISO', otherwise only the Ref tag gets populated with the document number  -->
												<!-- loop through all the documents that make part of the payment
												Exceptions apply to Bank A which will only allow one instance of Ustrd -->
												<xsl:variable name="remittancemsg">
													<xsl:for-each select="./PayableDocuments">
														<xsl:value-of select="./DocNumber"/>
														<xsl:choose>
															<xsl:when test="./DocType='CINV'">
																<xsl:value-of select="concat(';',./DocAmount/Value,';',./PaymentAmount/Value,';')"/>
															</xsl:when>
															<xsl:otherwise>
																<xsl:value-of select="concat(';-',./DocAmount/Value,';-',./PaymentAmount/Value,';')"/>
															</xsl:otherwise>
														</xsl:choose>
														<xsl:if test="not(./PurpPayment/DisplayValue='')">
															<xsl:value-of select="concat(./PurpPayment/DisplayValue,'|')"/>
														</xsl:if>
														<xsl:if test="./PurpPayment/DisplayValue=''">Payment for Goods and Services|</xsl:if>
													</xsl:for-each>
												</xsl:variable>
												<xsl:if test="not(//IntBankAccount/BankName='Bank A')">
													<xsl:for-each select="./PayableDocuments">
														<xsl:variable name="remittancemsgmult">
															<xsl:value-of select="./DocNumber"/>
															<xsl:choose>
																<xsl:when test="./DocType='CINV'">
																	<xsl:value-of select="concat(';',./DocAmount/Value,';',./PaymentAmount/Value,';')"/>
																</xsl:when>
																<xsl:otherwise>
																	<xsl:value-of select="concat(';-',./DocAmount/Value,';-',./PaymentAmount/Value,';')"/>
																</xsl:otherwise>
															</xsl:choose>
															<xsl:if test="not(./PurpPayment/DisplayValue='')">
																<xsl:value-of select="concat(./PurpPayment/DisplayValue,'|')"/>
															</xsl:if>
															<xsl:if test="./PurpPayment/DisplayValue=''">Payment for Goods and Services|</xsl:if>
														</xsl:variable>
														<Ustrd>
															<xsl:value-of select="substring($remittancemsgmult,1,140)"/>
														</Ustrd>
													</xsl:for-each>
												</xsl:if>
												<xsl:if test="(//IntBankAccount/BankName='Bank A')">
													<Ustrd>
														<xsl:value-of select="substring($remittancemsg,1,140)"/>
													</Ustrd>
												</xsl:if>
												<xsl:for-each select="./PayableDocuments">
													<Strd>
														<RfrdDocInf>
															<Tp>
																<CdOrPrtry>
																	<Cd>
																		<xsl:value-of select="./DocType"/>
																	</Cd>
																</CdOrPrtry>
															</Tp>
														</RfrdDocInf>
														<RfrdDocAmt>
															<xsl:if test="./DocType='CINV'">
																<RmtdAmt>
																	<xsl:attribute name="Ccy">
																		<xsl:value-of select="./DocAmount/Currency"/>
																	</xsl:attribute>
																	<xsl:value-of select="format-number(./DocAmount/Value,'#.00')"/>
																</RmtdAmt>
															</xsl:if>
															<xsl:if test="./DocType='CREN'">
																<CdtNoteAmt>
																	<xsl:attribute name="Ccy">
																		<xsl:value-of select="./DocAmount/Currency"/>
																	</xsl:attribute>
																	<xsl:value-of select="format-number(./DocAmount/Value,'#.00')"/>
																</CdtNoteAmt>
															</xsl:if>
														</RfrdDocAmt>
														<CdtrRefInf>
															<Tp>
																<CdOrPrtry>
																	<!-- hardcoded SCOR -->
																	<Cd>SCOR</Cd>
																</CdOrPrtry>
																<xsl:if test="not(./CreditReference='')">
																	<Issr>ISO</Issr>
																</xsl:if>
															</Tp>
															<xsl:if test="not(./CreditReference='')">
																<Ref>
																	<xsl:value-of select="./CreditReference"/>
																</Ref>
															</xsl:if>
															<xsl:if test="not(./CreditReference !='')">
																<Ref>
																	<xsl:value-of select="./DocNumber"/>
																</Ref>
															</xsl:if>
														</CdtrRefInf>
													</Strd>
												</xsl:for-each>
											</xsl:if>
										</RmtInf>
									</CdtTrfTxInf>
								</xsl:for-each>
							</PmtInf>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:for-each>
			</CstmrCdtTrfInitn>
		</Document>
	</xsl:template>
</xsl:stylesheet>