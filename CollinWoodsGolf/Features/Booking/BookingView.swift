import SwiftUI

/// Native booking flow: pick a day, pick an open Acuity slot, confirm.
struct BookingView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    let appointmentType: AppointmentType
    var onBooked: (Booking) -> Void

    @State private var selectedDate = Date.now
    @State private var slots: [TimeSlot] = []
    @State private var selectedSlot: TimeSlot?
    @State private var isLoadingSlots = true
    @State private var isBooking = false
    @State private var confirmedBooking: Booking?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            CWTheme.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AppointmentTypeCard(type: appointmentType)

                    DatePicker(
                        "Lesson date",
                        selection: $selectedDate,
                        in: Date.now...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(10)
                    .background(CWTheme.creamCard)
                    .clipShape(RoundedRectangle(cornerRadius: CWTheme.cornerRadius))
                    .onChange(of: selectedDate) {
                        Task { await loadSlots() }
                    }

                    CWSectionHeader(title: "Available Times")
                    if isLoadingSlots {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else if slots.isEmpty {
                        CWEmptyState(
                            icon: "calendar.badge.exclamationmark",
                            title: "No openings",
                            message: "Try another day, or message Coach Woods for off-calendar availability.")
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                            ForEach(slots) { slot in
                                Button {
                                    selectedSlot = slot
                                } label: {
                                    Text(slot.start, format: .dateTime.hour().minute())
                                        .font(CWTheme.body(15, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(slot == selectedSlot ? CWTheme.pine : CWTheme.creamCard)
                                        .foregroundStyle(slot == selectedSlot ? CWTheme.cream : CWTheme.charcoal)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(CWTheme.body(13))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await book() }
                    } label: {
                        if isBooking {
                            ProgressView().tint(CWTheme.cream)
                        } else {
                            Text(selectedSlot.map {
                                "Confirm \($0.start.formatted(date: .abbreviated, time: .shortened))"
                            } ?? "Select a time")
                        }
                    }
                    .buttonStyle(CWPrimaryButtonStyle())
                    .disabled(selectedSlot == nil || isBooking)
                }
                .padding(18)
            }
        }
        .navigationTitle("Book Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadSlots() }
        .alert(
            "Lesson booked",
            isPresented: Binding(
                get: { confirmedBooking != nil },
                set: { if !$0 { confirmedBooking = nil; dismiss() } })
        ) {
            Button("Done") {}
        } message: {
            if let confirmedBooking {
                Text("\(confirmedBooking.appointmentTypeName) on \(confirmedBooking.start.formatted(date: .complete, time: .shortened)). A confirmation from Acuity is on its way to your email.")
            }
        }
    }

    private func loadSlots() async {
        isLoadingSlots = true
        selectedSlot = nil
        slots = (try? await session.backend.availability(for: appointmentType, on: selectedDate)) ?? []
        isLoadingSlots = false
    }

    private func book() async {
        guard let selectedSlot else { return }
        isBooking = true
        errorMessage = nil
        do {
            let booking = try await session.backend.book(selectedSlot, type: appointmentType)
            onBooked(booking)
            confirmedBooking = booking
        } catch {
            errorMessage = "Booking failed — that slot may have just been taken. Pull to refresh and try again."
        }
        isBooking = false
    }
}

#Preview {
    NavigationStack {
        BookingView(appointmentType: MockData.appointmentTypes[0]) { _ in }
    }
    .environment(previewSession())
}
